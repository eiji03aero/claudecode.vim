" ClaudeCode Diff functionality
" Author: Claude Code
" License: MIT

if exists('g:loaded_claudecode_diff')
  finish
endif
let g:loaded_claudecode_diff = 1

" Global variables
let s:server_job = v:null
let s:server_channel = v:null
let s:server_port = 0
let s:port_file = expand('~/.cache/claudecode.vim/port')
let s:temp_dir = expand('~/.cache/claudecode.vim/diff')
let s:diff_data = {}
let s:reconnect_attempts = 0
let s:max_reconnect_attempts = 3

" Configuration
let g:claudecode_diff_enabled = get(g:, 'claudecode_diff_enabled', 1)
let g:claudecode_diff_auto_start = get(g:, 'claudecode_diff_auto_start', 1)
let g:claudecode_diff_timeout = get(g:, 'claudecode_diff_timeout', 30)

" Main initialization function
function! claudecode#diff#init() abort
  if !g:claudecode_diff_enabled
    return
  endif

  if !s:check_dependencies()
    return
  endif

  if !s:ensure_directories()
    return
  endif

  call s:start_server()
endfunction

" Check for required dependencies
function! s:check_dependencies() abort
  " Check vim-fugitive
  if !exists(':Gvdiffsplit')
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: vim-fugitive is required but not found'
    echohl None
    return 0
  endif

  " Check Node.js
  if !executable('node')
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: Node.js is required but not found'
    echohl None
    return 0
  endif

  " Check job/channel support
  if !has('job') || !has('channel')
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: Vim job/channel support is required'
    echohl None
    return 0
  endif

  return 1
endfunction

" Ensure required directories exist
function! s:ensure_directories() abort
  let cache_dir = fnamemodify(s:port_file, ':h')
  
  if !isdirectory(cache_dir)
    try
      call mkdir(cache_dir, 'p', 0700)
    catch
      echohl ErrorMsg
      echomsg 'ClaudeCode Diff: Failed to create cache directory: ' . cache_dir
      echohl None
      return 0
    endtry
  endif

  if !isdirectory(s:temp_dir)
    try
      call mkdir(s:temp_dir, 'p', 0700)
    catch
      echohl ErrorMsg
      echomsg 'ClaudeCode Diff: Failed to create temp directory: ' . s:temp_dir
      echohl None
      return 0
    endtry
  endif

  return 1
endfunction

" Start the MCP server
function! s:start_server() abort
  if s:server_job != v:null && job_status(s:server_job) == 'run'
    return
  endif

  let server_script = fnamemodify(expand('<sfile>'), ':h:h:h') . '/mcp-server/server.js'
  
  if !filereadable(server_script)
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: Server script not found: ' . server_script
    echohl None
    return
  endif

  let s:server_job = job_start(['node', server_script], {
    \ 'out_cb': function('s:server_output'),
    \ 'err_cb': function('s:server_error'),
    \ 'exit_cb': function('s:server_exit'),
    \ 'stoponexit': 'term'
    \ })

  if job_status(s:server_job) != 'run'
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: Failed to start server'
    echohl None
    return
  endif

  " Wait for server to start and write port file
  call timer_start(1000, function('s:connect_to_server'))
endfunction

" Connect to the MCP server via WebSocket
function! s:connect_to_server(timer) abort
  if !filereadable(s:port_file)
    if s:reconnect_attempts < s:max_reconnect_attempts
      let s:reconnect_attempts += 1
      call timer_start(1000, function('s:connect_to_server'))
    else
      echohl ErrorMsg
      echomsg 'ClaudeCode Diff: Failed to read port file after ' . s:max_reconnect_attempts . ' attempts'
      echohl None
    endif
    return
  endif

  let s:server_port = str2nr(readfile(s:port_file)[0])
  
  let s:server_channel = ch_open('localhost:' . s:server_port, {
    \ 'mode': 'json',
    \ 'callback': function('s:handle_message'),
    \ 'close_cb': function('s:connection_closed'),
    \ 'timeout': g:claudecode_diff_timeout * 1000
    \ })

  if ch_status(s:server_channel) != 'open'
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: Failed to connect to server on port ' . s:server_port
    echohl None
    return
  endif

  " Note: Vim client identification is now handled in claude_config.vim

  let s:reconnect_attempts = 0
  echo 'ClaudeCode Diff: Connected to server on port ' . s:server_port
endfunction

" Handle execute command message from server
function! s:handle_execute_command(data) abort
  if has_key(a:data, 'command')
    echom 'ClaudeCode: Executing command: ' . a:data.command
    try
      execute a:data.command
      echom 'ClaudeCode: Command executed successfully'
    catch
      echom 'ClaudeCode: Error executing command: ' . v:exception
    endtry
  endif
endfunction

" Handle incoming messages from server
function! s:handle_message(channel, message) abort
  let msg = a:message
  
  if type(msg) != type({})
    return
  endif

  if msg.type == 'show_diff'
    call s:show_diff(msg)
  elseif msg.type == 'ping'
    call s:handle_ping(msg)
  elseif msg.type == 'error'
    call s:handle_error(msg)
  elseif msg.type == 'execute_command'
    call s:handle_execute_command(msg)
  endif
endfunction

" Show diff in new tab using vim-fugitive
function! s:show_diff(data) abort
  let diff_id = a:data.id
  let temp_original = a:data.temp_original
  let temp_modified = a:data.temp_modified
  let file_path = a:data.file_path

  " Store diff data for later use
  let s:diff_data[diff_id] = {
    \ 'temp_original': temp_original,
    \ 'temp_modified': temp_modified,
    \ 'file_path': file_path
    \ }

  " Create new tab and show diff
  tabnew
  let t:claudecode_diff_id = diff_id
  
  try
    execute 'edit ' . fnameescape(temp_original)
    execute 'Gvdiffsplit ' . fnameescape(temp_modified)
    
    " Set up buffer-local commands
    command! -buffer ClaudeCodeDiffAccept call claudecode#diff#accept()
    command! -buffer ClaudeCodeDiffReject call claudecode#diff#reject()
    
    " Set buffer names for clarity
    execute 'file [Original] ' . fnamemodify(file_path, ':t')
    wincmd w
    execute 'file [Modified] ' . fnamemodify(file_path, ':t')
    
    echo 'ClaudeCode Diff: Use :ClaudeCodeDiffAccept or :ClaudeCodeDiffReject'
  catch
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: Failed to show diff - ' . v:exception
    echohl None
    tabclose
  endtry
endfunction

" Accept the diff
function! claudecode#diff#accept() abort
  if !exists('t:claudecode_diff_id')
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: No active diff in this tab'
    echohl None
    return
  endif

  let diff_id = t:claudecode_diff_id
  let diff_data = get(s:diff_data, diff_id, {})
  
  if empty(diff_data)
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: Diff data not found'
    echohl None
    return
  endif

  " Send accept response to server
  call s:send_diff_response(diff_id, 'accept')
  
  " Apply the changes
  try
    let modified_content = readfile(diff_data.temp_modified)
    call writefile(modified_content, diff_data.file_path)
    echo 'ClaudeCode Diff: Changes accepted and applied to ' . diff_data.file_path
  catch
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: Failed to apply changes - ' . v:exception
    echohl None
  endtry
  
  call s:cleanup_diff(diff_id)
endfunction

" Reject the diff
function! claudecode#diff#reject() abort
  if !exists('t:claudecode_diff_id')
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: No active diff in this tab'
    echohl None
    return
  endif

  let diff_id = t:claudecode_diff_id
  
  call s:send_diff_response(diff_id, 'reject')
  call s:cleanup_diff(diff_id)
  
  echo 'ClaudeCode Diff: Changes rejected'
endfunction

" Send diff response to server
function! s:send_diff_response(diff_id, action) abort
  if ch_status(s:server_channel) != 'open'
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: Not connected to server'
    echohl None
    return
  endif

  call ch_sendexpr(s:server_channel, {
    \ 'type': 'diff_response',
    \ 'id': a:diff_id,
    \ 'action': a:action
    \ })
endfunction

" Cleanup diff data and close tab
function! s:cleanup_diff(diff_id) abort
  " Remove from diff data
  if has_key(s:diff_data, a:diff_id)
    unlet s:diff_data[a:diff_id]
  endif
  
  " Close tab
  tabclose
endfunction

" Reconnect to server
function! claudecode#diff#reconnect() abort
  call s:disconnect()
  let s:reconnect_attempts = 0
  call s:start_server()
endfunction

" Disconnect from server
function! s:disconnect() abort
  if s:server_channel != v:null
    call ch_close(s:server_channel)
    let s:server_channel = v:null
  endif
endfunction

" Handle ping from server
function! s:handle_ping(data) abort
  if ch_status(s:server_channel) == 'open'
    call ch_sendexpr(s:server_channel, {
      \ 'type': 'pong',
      \ 'id': a:data.id
      \ })
  endif
endfunction

" Handle error from server
function! s:handle_error(data) abort
  echohl ErrorMsg
  echomsg 'ClaudeCode Diff Error: ' . a:data.message
  echohl None
endfunction

" Server output callback
function! s:server_output(channel, message) abort
  " Log server output if needed
  if exists('g:claudecode_diff_debug') && g:claudecode_diff_debug
    echomsg 'Server: ' . a:message
  endif
endfunction

" Server error callback
function! s:server_error(channel, message) abort
  echohl ErrorMsg
  echomsg 'ClaudeCode Diff Server Error: ' . a:message
  echohl None
endfunction

" Server exit callback
function! s:server_exit(job, exit_status) abort
  let s:server_job = v:null
  let s:server_channel = v:null
  
  if a:exit_status != 0
    echohl ErrorMsg
    echomsg 'ClaudeCode Diff: Server exited with status ' . a:exit_status
    echohl None
  endif
endfunction

" Connection closed callback
function! s:connection_closed(channel) abort
  let s:server_channel = v:null
  echo 'ClaudeCode Diff: Connection to server closed'
endfunction

" Get server status
function! claudecode#diff#status() abort
  if s:server_job != v:null && job_status(s:server_job) == 'run'
    if s:server_channel != v:null && ch_status(s:server_channel) == 'open'
      echo 'ClaudeCode Diff: Connected to server on port ' . s:server_port
    else
      echo 'ClaudeCode Diff: Server running but not connected'
    endif
  else
    echo 'ClaudeCode Diff: Server not running'
  endif
endfunction

" Cleanup on VimLeave
function! claudecode#diff#cleanup() abort
  call s:disconnect()
  
  if s:server_job != v:null
    call job_stop(s:server_job)
    let s:server_job = v:null
  endif
  
  " Remove port file
  if filereadable(s:port_file)
    call delete(s:port_file)
  endif
endfunction

" Auto-initialize if enabled
if g:claudecode_diff_auto_start
  augroup claudecode_diff
    autocmd!
    autocmd VimEnter * call claudecode#diff#init()
    autocmd VimLeave * call claudecode#diff#cleanup()
  augroup END
endif

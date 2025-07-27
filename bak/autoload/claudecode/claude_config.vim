" claudecode.vim Claude IDE configuration generator
" Author: Claude Code
" Description: Generates and manages .claude/ide configuration for Claude Code integration

" Get the script file path at script level (not inside a function)
let s:script_dir = fnamemodify(expand('<sfile>'), ':p:h:h:h')
let s:server_port = 0
let s:server_channel = v:null

function! claudecode#claude_config#generate()
  " Generate .claude configuration for Claude Code and create lock file
  let l:project_root = s:get_project_root()
  let l:claude_dir = l:project_root . '/.claude'
  
  " Create .claude directory if it doesn't exist
  if !isdirectory(l:claude_dir)
    call mkdir(l:claude_dir, 'p')
  endif
  
  " Start MCP server if not running
  call s:start_mcp_server()
  
  let l:port = s:get_server_port()
  if l:port > 0
    " Set environment variable
    let l:lock_file = s:create_lock_file(l:port)
    if !empty(l:lock_file)
      echom 'claudecode.vim: Generated Claude Code configuration at ' . l:claude_dir
      echom 'claudecode.vim: Created lock file at ' . l:lock_file
    else
      echom 'claudecode.vim: Generated Claude Code configuration at ' . l:claude_dir . ' (lock file creation failed)'
    endif
  else
    echom 'claudecode.vim: Generated Claude Code configuration at ' . l:claude_dir . ' (no server port available)'
  endif
  
  return l:claude_dir
endfunction

function! claudecode#claude_config#update()
  " Update existing configuration
  return claudecode#claude_config#generate()
endfunction

function! claudecode#claude_config#remove()
  " Remove Claude Code configuration and lock file
  let l:project_root = s:get_project_root()
  let l:claude_dir = l:project_root . '/.claude'
  
  " Get port number and remove lock file
  let l:port = s:get_server_port()
  if l:port > 0
    call s:remove_lock_file(l:port)
  endif
  
  " Stop MCP server
  call s:stop_mcp_server()
  
  if isdirectory(l:claude_dir)
    call delete(l:claude_dir, 'rf')
    echom 'claudecode.vim: Removed Claude Code configuration and lock file'
  else
    echom 'claudecode.vim: Removed lock file'
  endif
endfunction

function! s:get_project_root()
  " Get project root directory
  let l:current_dir = expand('%:p:h')
  if empty(l:current_dir)
    let l:current_dir = getcwd()
  endif
  
  " Look for common project root indicators
  let l:indicators = ['.git', '.hg', '.svn', 'package.json', 'Cargo.toml', 'pyproject.toml', 'go.mod']
  
  let l:dir = l:current_dir
  while l:dir != '/'
    for l:indicator in l:indicators
      if isdirectory(l:dir . '/' . l:indicator) || filereadable(l:dir . '/' . l:indicator)
        return l:dir
      endif
    endfor
    let l:dir = fnamemodify(l:dir, ':h')
  endwhile
  
  " Fallback to current directory
  return l:current_dir
endfunction

function! s:generate_uuid()
  " Generate a simple UUID v4
  let l:hex = '0123456789abcdef'
  let l:uuid = ''
  
  for l:i in range(32)
    if l:i == 8 || l:i == 12 || l:i == 16 || l:i == 20
      let l:uuid .= '-'
    endif
    
    if l:i == 12
      let l:uuid .= '4'  " Version 4
    elseif l:i == 16
      let l:uuid .= l:hex[and(or(localtime() + l:i, 0x8), 0xb)]  " Variant bits
    else
      let l:uuid .= l:hex[and(localtime() + l:i + getpid(), 0xf)]
    endif
  endfor
  
  return l:uuid
endfunction

function! s:get_vim_pid()
  " Get Vim process ID
  return getpid()
endfunction

function! s:get_workspace_folders()
  " Get workspace folders (current working directory)
  let l:cwd = getcwd()
  return [l:cwd]
endfunction

function! s:get_server_port()
  " Return cached port if already set
  if s:server_port > 0
    return s:server_port
  endif
  
  " Find an unused TCP port
  let s:server_port = s:find_unused_port()
  return s:server_port
endfunction

function! s:find_unused_port()
  " Find an unused TCP port by trying to bind to it
  for l:port in range(8000, 9000)
    let l:result = system('nc -z localhost ' . l:port . ' 2>/dev/null; echo $?')
    if str2nr(trim(l:result)) != 0
      " Port is not in use
      return l:port
    endif
  endfor
  
  " Fallback to a random port in higher range
  return 8000 + (localtime() % 1000)
endfunction

function! s:wait_for_server_port()
  " Wait for server to start and write port file
  let l:max_attempts = 10
  let l:attempt = 0
  
  while l:attempt < l:max_attempts
    let l:port = s:get_server_port()
    if l:port > 0
      return l:port
    endif
    
    sleep 500m
    let l:attempt += 1
  endwhile
  
  return 0
endfunction

" Global variables for MCP server management
let s:mcp_server_job = v:null

function! s:start_mcp_server()
  echom "starting start_mcp_server 1"
  " Start MCP server if not already running
  if s:mcp_server_job != v:null && job_status(s:mcp_server_job) == 'run'
    return
  endif

  echom "starting start_mcp_server 2"
  " Check if server is already running by checking port file
  let l:port = s:get_server_port()

  echom "starting start_mcp_server 3: " . s:script_dir
  let l:server_script = s:script_dir . '/mcp-server/server.js'
  echom l:server_script
  
  if !filereadable(l:server_script)
    echohl WarningMsg
    echom 'claudecode.vim: MCP server script not found: ' . l:server_script
    echohl None
    return
  endif

  " Create cache directory if it doesn't exist
  let l:cache_dir = expand('~/.cache/claudecode.vim')
  if !isdirectory(l:cache_dir)
    try
      call mkdir(l:cache_dir, 'p', 0700)
    catch
      echohl ErrorMsg
      echom 'claudecode.vim: Failed to create cache directory: ' . l:cache_dir
      echohl None
      return
    endtry
  endif

  let s:mcp_server_job = job_start(['node', l:server_script], {
    \ 'out_cb': function('s:mcp_server_output'),
    \ 'err_cb': function('s:mcp_server_error'),
    \ 'exit_cb': function('s:mcp_server_exit'),
    \ 'env': {'CLAUDE_CODE_SSE_PORT': l:port, 'ENABLE_IDE_INTEGRATION': "true", 'FORCE_CODE_TERMINAL': "true", 'VIM_PROCESS_ID': string(getpid()) },
    \ 'stoponexit': 'term'
    \ })

  if job_status(s:mcp_server_job) == 'run'
    echom 'claudecode.vim: MCP server started on port: ' . l:port
    
    " Connect to server and identify as Vim client
    call timer_start(1000, function('s:connect_and_identify_to_server'))
  else
    echohl ErrorMsg
    echom 'claudecode.vim: Failed to start MCP server'
    echohl None
  endif
endfunction

function! s:mcp_server_output(channel, msg)
  " Handle MCP server stdout
  if match(a:msg, 'MCP server started on port') >= 0
    echom 'claudecode.vim: ' . a:msg
  endif
endfunction

function! s:mcp_server_error(channel, msg)
  " Handle MCP server stderr
  echohl ErrorMsg
  echom 'claudecode.vim MCP server error: ' . a:msg
  echohl None
endfunction

function! s:mcp_server_exit(job, exit_status)
  " Handle MCP server exit
  let s:mcp_server_job = v:null
  if a:exit_status != 0
    echohl ErrorMsg
    echom 'claudecode.vim: MCP server exited with status ' . a:exit_status
    echohl None
  endif
endfunction

function! s:stop_mcp_server()
  " Close server channel if open
  if s:server_channel != v:null && ch_status(s:server_channel) == 'open'
    call ch_close(s:server_channel)
    let s:server_channel = v:null
  endif
  
  " Stop MCP server if running
  if s:mcp_server_job != v:null && job_status(s:mcp_server_job) == 'run'
    call job_stop(s:mcp_server_job, 'term')
    let s:mcp_server_job = v:null
  endif
endfunction

function! s:create_lock_file(port)
  " Create lock file according to lock_spec.md
  let l:claude_ide_dir = expand('~/.claude/ide')
  
  " Create directory if it doesn't exist
  if !isdirectory(l:claude_ide_dir)
    call mkdir(l:claude_ide_dir, 'p')
  endif
  
  let l:pid = s:get_vim_pid()
  let l:lock_file = l:claude_ide_dir . '/' . a:port . '.lock'
  
  let l:lock_data = {
    \ 'pid': string(l:pid),
    \ 'workspaceFolders': s:get_workspace_folders(),
    \ 'ideName': 'Vim',
    \ 'transport': 'ws',
    \ 'authToken': s:generate_uuid()
    \ }
  
  let l:json_content = s:to_json(l:lock_data)
  
  try
    call writefile([l:json_content], l:lock_file)
    return l:lock_file
  catch
    echohl ErrorMsg
    echom 'claudecode.vim: Failed to create lock file: ' . v:exception
    echohl None
    return ''
  endtry
endfunction

function! s:remove_lock_file(port)
  " Remove lock file when Vim exits
  let l:claude_ide_dir = expand('~/.claude/ide')
  let l:lock_file = l:claude_ide_dir . '/' . a:port . '.lock'
  
  if filereadable(l:lock_file)
    call delete(l:lock_file)
  endif
endfunction

function! s:to_json(value)
  " Convert value to JSON string
  if type(a:value) == type({})
    let l:items = []
    for [l:key, l:val] in items(a:value)
      call add(l:items, '"' . l:key . '": ' . s:to_json(l:val))
    endfor
    return '{' . join(l:items, ', ') . '}'
  elseif type(a:value) == type([])
    let l:items = []
    for l:item in a:value
      call add(l:items, s:to_json(l:item))
    endfor
    return '[' . join(l:items, ', ') . ']'
  elseif type(a:value) == type('')
    return '"' . substitute(a:value, '"', '\\"', 'g') . '"'
  elseif type(a:value) == type(0)
    return string(a:value)
  else
    return 'null'
  endif
endfunction

" Auto-generate configuration on plugin load and cleanup on exit
" Connect to MCP server and identify as Vim client
function! s:connect_and_identify_to_server(timer) abort
  let l:port = s:get_server_port()
  let s:server_channel = ch_open('localhost:' . l:port, {
    \ 'mode': 'json',
    \ 'timeout': 5000,
    \ 'callback': function('s:handle_message'),
    \ 'err_cb': function('s:channel_error'),
    \ 'close_cb': function('s:channel_closed')
    \ })

  echom 'ch_open-ed: ' . s:server_channel
  echom 'ch_open-ed: ' . ch_status(s:server_channel)
  if ch_status(s:server_channel) == 'open'
    " Identify as Vim client
    call ch_sendexpr(s:server_channel, {
      \ 'type': 'identify',
      \ 'id': 'vim_init',
      \ 'client_type': 'vim'
      \ })
    echom 'claudecode.vim: Connected and identified to MCP server'
  else
    echom 'claudecode.vim: Failed to connect to MCP server on port ' . l:port
  endif
endfunction

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

function! s:channel_error(channel, msg)
  echom 'Channel error: ' . a:msg
endfunction

function! s:channel_closed(channel)
  echom 'Channel closed'
endfunction

augroup claudecode_claude_config
  autocmd!
  autocmd VimEnter * call claudecode#claude_config#generate()
  autocmd VimLeave * call claudecode#claude_config#remove()
augroup END

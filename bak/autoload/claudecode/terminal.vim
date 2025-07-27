" claudecode.vim terminal management
" Author: Claude Code
" Description: Manages Claude CLI terminal sessions

let s:terminal_buffer_name = "claudecode_terminal"
let s:terminal_job_id = v:null

function! claudecode#terminal#exists()
  " Check if Claude terminal exists and is running
  let l:bufnr = bufnr(s:terminal_buffer_name)
  if l:bufnr == -1
    return 0
  endif
  
  " Check if buffer still exists and has a valid terminal
  if !bufexists(l:bufnr)
    return 0
  endif
  
  " For Vim 8+, check if terminal is still running
  if has('terminal')
    let l:status = term_getstatus(l:bufnr)
    return l:status =~# 'running'
  endif
  
  return 1
endfunction

function! claudecode#terminal#get_buffer_name()
  " Get the terminal buffer name
  return s:terminal_buffer_name
endfunction

function! claudecode#terminal#get_command(args)
  " Generate Claude CLI command with arguments
  let l:cmd = "claude --ide --debug"
  if len(a:args) > 0
    let l:cmd .= " " . join(a:args, " ")
  endif
  return l:cmd
endfunction

function! claudecode#terminal#get_split_command()
  " Generate split command based on configuration
  let l:position = claudecode#config#get('terminal_position')
  
  if l:position == 'right'
    let l:width = claudecode#config#get('terminal_width')
    return 'rightbelow vertical ' . l:width . 'split'
  elseif l:position == 'bottom'
    let l:height = claudecode#config#get('terminal_height')
    return l:height . 'split'
  else
    throw "claudecode: Invalid terminal position: " . l:position
  endif
endfunction

function! claudecode#terminal#open(args)
  " Open or focus Claude terminal
  if claudecode#terminal#exists()
    " Terminal exists, just focus it
    let l:bufnr = bufnr(s:terminal_buffer_name)
    let l:winnr = bufwinnr(l:bufnr)
    if l:winnr != -1
      execute l:winnr . 'wincmd w'
      return 1
    endif
  endif
  
  " Create new terminal
  try
    let l:split_cmd = claudecode#terminal#get_split_command()
    execute l:split_cmd
    
    let l:claude_cmd = claudecode#terminal#get_command(a:args)
    
    if has('terminal')
      " Vim 8+ terminal
      let l:bufnr = term_start(l:claude_cmd, {
        \ 'term_name': s:terminal_buffer_name, 
        \ 'curwin': 1,
        \ 'term_kill': 'term',
        \ 'exit_cb': 'claudecode#terminal#on_exit'
        \ })
      let s:terminal_job_id = term_getjob(l:bufnr)
    else
      " Fallback for older Vim versions
      execute '!tmux new-session -d -s claude_session "' . l:claude_cmd . '"'
      execute 'edit term://tmux attach-session -t claude_session'
      execute 'file ' . s:terminal_buffer_name
    endif
    
    return 1
  catch
    echohl ErrorMsg
    echo "claudecode.vim: Failed to open terminal: " . v:exception
    echohl None
    return 0
  endtry
endfunction

function! claudecode#terminal#close()
  " Close Claude terminal
  let l:bufnr = bufnr(s:terminal_buffer_name)
  if l:bufnr != -1
    " Close terminal job if running
    if has('terminal') && s:terminal_job_id != v:null
      try
        " s:terminal_job_id is already a job object, not a number
        call job_stop(s:terminal_job_id)
      catch
        " Ignore errors when stopping job
      endtry
    endif
    
    " Close buffer
    execute 'bdelete! ' . l:bufnr
    let s:terminal_job_id = v:null
    return 1
  endif
  return 0
endfunction

function! claudecode#terminal#send(text)
  " Send text to Claude terminal
  if !claudecode#terminal#exists()
    echohl ErrorMsg
    echo "claudecode.vim: No active Claude terminal"
    echohl None
    return 0
  endif
  
  let l:bufnr = bufnr(s:terminal_buffer_name)
  if l:bufnr == -1
    return 0
  endif
  
  try
    if has('terminal')
      " Send text to terminal
      call term_sendkeys(l:bufnr, a:text . "\<CR>")
    else
      " Fallback: write to file and source in tmux
      call writefile([a:text], '/tmp/claudecode_input')
      execute '!tmux send-keys -t claude_session "$(cat /tmp/claudecode_input)" Enter'
    endif
    
    " Focus the terminal window
    let l:winnr = bufwinnr(l:bufnr)
    if l:winnr != -1
      execute l:winnr . 'wincmd w'
    endif
    
    return 1
  catch
    echohl ErrorMsg
    echo "claudecode.vim: Failed to send text to terminal: " . v:exception
    echohl None
    return 0
  endtry
endfunction

function! claudecode#terminal#on_exit(job, exit_status)
  " Callback when Claude CLI exits
  try
    " Close the terminal buffer
    let l:bufnr = bufnr(s:terminal_buffer_name)
    if l:bufnr != -1
      execute 'bdelete! ' . l:bufnr
    endif
    
    " Reset terminal job ID
    let s:terminal_job_id = v:null
    
    " Close the window if it was opened in a split
    " Try to return to the previous window
    wincmd p
  catch
    " Ignore any errors during cleanup
  endtry
endfunction

function! claudecode#terminal#focus()
  " Focus the Claude terminal window
  if claudecode#terminal#exists()
    let l:bufnr = bufnr(s:terminal_buffer_name)
    let l:winnr = bufwinnr(l:bufnr)
    if l:winnr != -1
      execute l:winnr . 'wincmd w'
      return 1
    endif
  endif
  return 0
endfunction

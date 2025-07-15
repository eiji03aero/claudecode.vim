" claudecode.vim dependency validation
" Author: Claude Code
" Description: Validates required dependencies for claudecode.vim

function! claudecode#deps#check_claude_cli()
  " Check if Claude CLI is available in PATH
  return executable('claude')
endfunction

function! claudecode#deps#check_fugitive()
  " Check if vim-fugitive is loaded and available
  return exists(':Git') && exists('*fugitive#Head')
endfunction

function! claudecode#deps#validate_all()
  " Validate all required dependencies
  let l:claude_ok = claudecode#deps#check_claude_cli()
  let l:fugitive_ok = claudecode#deps#check_fugitive()
  
  if !l:claude_ok
    echohl ErrorMsg
    echo "claudecode.vim: Claude CLI not found in PATH. Please install Claude CLI."
    echohl None
  endif
  
  if !l:fugitive_ok
    echohl ErrorMsg
    echo "claudecode.vim: vim-fugitive not available. Please install tpope/vim-fugitive."
    echohl None
  endif
  
  return l:claude_ok && l:fugitive_ok
endfunction

function! claudecode#deps#get_missing_deps()
  " Return list of missing dependencies
  let l:missing = []
  
  if !claudecode#deps#check_claude_cli()
    call add(l:missing, 'claude')
  endif
  
  if !claudecode#deps#check_fugitive()
    call add(l:missing, 'vim-fugitive')
  endif
  
  return l:missing
endfunction

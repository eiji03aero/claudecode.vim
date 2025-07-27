" claudecode.vim configuration management
" Author: Claude Code
" Description: Manages plugin configuration and settings

" Default configuration values
let s:defaults = {
  \ 'terminal_position': 'right',
  \ 'terminal_width': 80,
  \ 'terminal_height': 40
  \ }

function! claudecode#config#get(key)
  " Get configuration value with fallback to default
  let l:var_name = 'g:claudecode_' . a:key
  
  if exists(l:var_name)
    return eval(l:var_name)
  endif
  
  if has_key(s:defaults, a:key)
    return s:defaults[a:key]
  endif
  
  throw "claudecode: Unknown configuration key: " . a:key
endfunction

function! claudecode#config#set(key, value)
  " Set configuration value
  let l:var_name = 'g:claudecode_' . a:key
  execute 'let ' . l:var_name . ' = ' . string(a:value)
endfunction

function! claudecode#config#validate()
  " Validate current configuration
  try
    " Validate terminal position
    let l:position = claudecode#config#get('terminal_position')
    if l:position != 'right' && l:position != 'bottom'
      echohl ErrorMsg
      echo "claudecode.vim: Invalid terminal_position '" . l:position . "'. Must be 'right' or 'bottom'."
      echohl None
      return 0
    endif
    
    " Validate terminal width
    let l:width = claudecode#config#get('terminal_width')
    if type(l:width) != type(0) || l:width <= 0
      echohl ErrorMsg
      echo "claudecode.vim: Invalid terminal_width '" . l:width . "'. Must be a positive integer."
      echohl None
      return 0
    endif
    
    " Validate terminal height
    let l:height = claudecode#config#get('terminal_height')
    if type(l:height) != type(0) || l:height <= 0
      echohl ErrorMsg
      echo "claudecode.vim: Invalid terminal_height '" . l:height . "'. Must be a positive integer."
      echohl None
      return 0
    endif
    
    return 1
  catch
    echohl ErrorMsg
    echo "claudecode.vim: Configuration validation error: " . v:exception
    echohl None
    return 0
  endtry
endfunction

function! claudecode#config#get_all()
  " Get all configuration values
  let l:config = {}
  for l:key in keys(s:defaults)
    let l:config[l:key] = claudecode#config#get(l:key)
  endfor
  return l:config
endfunction

function! claudecode#config#reset()
  " Reset all configuration to defaults
  for l:key in keys(s:defaults)
    let l:var_name = 'g:claudecode_' . l:key
    if exists(l:var_name)
      execute 'unlet ' . l:var_name
    endif
  endfor
endfunction

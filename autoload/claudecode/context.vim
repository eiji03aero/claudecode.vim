" claudecode.vim context processing
" Author: Claude Code
" Description: Handles text and file context formatting for Claude CLI

function! claudecode#context#get_relative_path(filepath)
  " Convert absolute path to relative path from current working directory
  let l:cwd = getcwd()
  let l:filepath = fnamemodify(a:filepath, ':p')
  
  " Check if file is within current working directory
  if stridx(l:filepath, l:cwd . '/') == 0
    " Remove cwd prefix and leading slash
    return strpart(l:filepath, len(l:cwd) + 1)
  endif
  
  " Return absolute path if not within cwd
  return l:filepath
endfunction

function! claudecode#context#format_buffer(filename)
  " Format buffer context for Claude CLI
  let l:rel_path = claudecode#context#get_relative_path(a:filename)
  return '@' . l:rel_path
endfunction

function! claudecode#context#format_selection(filename, lines, start_line, end_line)
  " Format selection context with filename and line numbers
  let l:rel_path = claudecode#context#get_relative_path(a:filename)
  let l:header = '@' . l:rel_path . '#L' . a:start_line . '-' . a:end_line
  
  let l:content_lines = [l:header]
  call extend(l:content_lines, a:lines)
  
  return join(l:content_lines, "\n")
endfunction

function! claudecode#context#get_visual_selection()
  " Get the current visual selection as lines
  let l:start_pos = getpos("'<")
  let l:end_pos = getpos("'>")
  
  let l:start_line = l:start_pos[1]
  let l:end_line = l:end_pos[1]
  
  " Get the selected lines
  let l:lines = getline(l:start_line, l:end_line)
  
  " Handle partial line selection for single line
  if l:start_line == l:end_line
    let l:start_col = l:start_pos[2] - 1
    let l:end_col = l:end_pos[2]
    if len(l:lines) > 0
      let l:lines[0] = strpart(l:lines[0], l:start_col, l:end_col - l:start_col)
    endif
  endif
  
  return {'lines': l:lines, 'start_line': l:start_line, 'end_line': l:end_line}
endfunction

function! claudecode#context#get_buffer_content()
  " Get the current buffer content
  let l:lines = getline(1, '$')
  let l:filename = expand('%')
  
  if empty(l:filename)
    let l:filename = '[No Name]'
  endif
  
  return {'lines': l:lines, 'filename': l:filename}
endfunction

function! claudecode#context#prepare_selection_for_claude()
  " Prepare current visual selection for sending to Claude
  let l:selection = claudecode#context#get_visual_selection()
  let l:filename = expand('%')
  
  if empty(l:filename)
    let l:filename = '[No Name]'
  endif
  
  return claudecode#context#format_selection(l:filename, l:selection.lines, l:selection.start_line, l:selection.end_line)
endfunction

function! claudecode#context#prepare_buffer_for_claude()
  " Prepare current buffer for sending to Claude
  let l:buffer = claudecode#context#get_buffer_content()
  return claudecode#context#format_buffer(l:buffer.filename)
endfunction
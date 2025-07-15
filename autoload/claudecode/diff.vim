" claudecode.vim diff integration
" Author: Claude Code
" Description: Integrates with vim-fugitive for diff viewing

function! claudecode#diff#is_diff_line(line)
  " Check if a line is part of a diff output
  let l:line = a:line
  
  " Git diff patterns
  if l:line =~# '^diff --git'
    return 1
  endif
  
  " Traditional diff patterns
  if l:line =~# '^---\s'
    return 1
  endif
  
  if l:line =~# '^+++\s'
    return 1
  endif
  
  " Unified diff hunk headers
  if l:line =~# '^@@.*@@'
    return 1
  endif
  
  " Index lines
  if l:line =~# '^index\s'
    return 1
  endif
  
  return 0
endfunction

function! claudecode#diff#extract_filename(diff_header)
  " Extract filename from diff header line
  let l:line = a:diff_header
  
  " Handle git diff format: diff --git a/file b/file
  let l:git_match = matchlist(l:line, '^diff --git a/\([^ ]\+\) b/\([^ ]\+\)')
  if !empty(l:git_match)
    return l:git_match[2]  " Use the 'b/' version (new file)
  endif
  
  " Handle traditional diff format: --- a/file or +++ b/file
  let l:trad_match = matchlist(l:line, '^[+-]\{3\}\s\+[ab]/\([^ \t]\+\)')
  if !empty(l:trad_match)
    return l:trad_match[1]
  endif
  
  " Fallback: try to extract any filename-like pattern
  let l:file_match = matchlist(l:line, '\([a-zA-Z0-9_./\\-]\+\)\.\w\+')
  if !empty(l:file_match)
    return l:file_match[0]
  endif
  
  return ''
endfunction

function! claudecode#diff#extract_diff_blocks(lines)
  " Extract diff blocks from text lines
  let l:blocks = []
  let l:current_block = {}
  let l:in_diff = 0
  
  for l:i in range(len(a:lines))
    let l:line = a:lines[l:i]
    
    if claudecode#diff#is_diff_line(l:line)
      if !l:in_diff
        " Starting new diff block
        let l:current_block = {
          \ 'start': l:i,
          \ 'end': l:i,
          \ 'filename': '',
          \ 'lines': []
          \ }
        let l:in_diff = 1
      endif
      
      " Update end position
      let l:current_block.end = l:i
      call add(l:current_block.lines, l:line)
      
      " Try to extract filename
      if empty(l:current_block.filename)
        let l:filename = claudecode#diff#extract_filename(l:line)
        if !empty(l:filename)
          let l:current_block.filename = l:filename
        endif
      endif
    else
      if l:in_diff
        " Check if this might still be part of diff (like diff content lines)
        if l:line =~# '^[+ -]' || l:line =~# '^\\' || empty(trim(l:line))
          " Continue the diff block
          let l:current_block.end = l:i
          call add(l:current_block.lines, l:line)
        else
          " End of diff block
          call add(l:blocks, l:current_block)
          let l:in_diff = 0
          let l:current_block = {}
        endif
      endif
    endif
  endfor
  
  " Add final block if we're still in a diff
  if l:in_diff && !empty(l:current_block)
    call add(l:blocks, l:current_block)
  endif
  
  return l:blocks
endfunction

function! claudecode#diff#detect_and_open(terminal_buffer)
  " Detect diff output in terminal and open with vim-fugitive
  if !claudecode#deps#check_fugitive()
    return 0
  endif
  
  let l:bufnr = bufnr(a:terminal_buffer)
  if l:bufnr == -1
    return 0
  endif
  
  " Get terminal content
  let l:lines = getbufline(l:bufnr, 1, '$')
  
  " Extract diff blocks
  let l:diff_blocks = claudecode#diff#extract_diff_blocks(l:lines)
  
  if empty(l:diff_blocks)
    return 0
  endif
  
  " Open the first diff block with fugitive
  let l:first_diff = l:diff_blocks[0]
  
  if !empty(l:first_diff.filename)
    try
      " Try to open the file and show diff
      execute 'tabnew'
      execute 'edit' l:first_diff.filename
      
      " Check if file exists and try to show git diff
      if filereadable(l:first_diff.filename)
        execute 'Gdiffsplit'
      else
        " If file doesn't exist, create a scratch buffer with diff content
        execute 'enew'
        call setline(1, l:first_diff.lines)
        setlocal buftype=nofile
        setlocal filetype=diff
      endif
      
      echo "Opened diff for: " . l:first_diff.filename
      return 1
    catch
      echohl ErrorMsg
      echo "claudecode.vim: Failed to open diff: " . v:exception
      echohl None
      return 0
    endtry
  endif
  
  return 0
endfunction

function! claudecode#diff#auto_detect()
  " Auto-detect diff in Claude terminal and offer to open
  let l:terminal_name = claudecode#terminal#get_buffer_name()
  
  if claudecode#diff#detect_and_open(l:terminal_name)
    return 1
  endif
  
  return 0
endfunction
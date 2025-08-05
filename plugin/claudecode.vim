" claudecode.vim - Vim plugin for Claude Code CLI integration
" Version: 1.0.0
" Author: Claude AI

if exists('g:loaded_claudecode')
  finish
endif
let g:loaded_claudecode = 1

" Check for required Vim features
if !has('terminal') || !has('job')
  echohl ErrorMsg
  echom 'claudecode.vim requires terminal and job support'
  echohl None
  finish
endif

" Default configuration
let g:claudecode_terminal_position = get(g:, 'claudecode_terminal_position', 'rightbelow')
let g:claudecode_terminal_width = get(g:, 'claudecode_terminal_width', 80)
let g:claudecode_terminal_height = get(g:, 'claudecode_terminal_height', 40)

" Debug mode
let g:claudecode_debug = get(g:, 'claudecode_debug', 0)

" Commands
command! -nargs=* ClaudeCode call claudecode#launch(<q-args>)
command! ClaudeCodeQuit call claudecode#quit()
command! ClaudeCodeStart call claudecode#mcp_start()
command! ClaudeCodeStop call claudecode#mcp_stop()
command! ClaudeCodeStatus echo claudecode#mcp_get_status()
command! ClaudeCodeOpenLog call claudecode#open_log()

" Additional commands
command! -range ClaudeCodeSendSelection call claudecode#send_selection()
command! ClaudeCodeSendBuffer call claudecode#send_buffer()

function! ClaudeCodeGetPluginDirectory()
    return claudecode#get_plugin_directory()
endfunction

" Auto-cleanup MCP server on exit
augroup ClaudeCodeMCP
    autocmd!
    " Cleanup MCP server on exit
    autocmd VimLeave * call claudecode#mcp_cleanup()
augroup END

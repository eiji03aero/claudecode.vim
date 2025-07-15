" claudecode.vim - Vim plugin for Claude Code CLI integration
" Author: Claude Code
" Version: 1.0.0
" Description: Integrates Claude Code CLI with Vim

" Prevent loading if already loaded or if Vim is too old
if exists('g:loaded_claudecode') || &compatible || v:version < 700
  finish
endif
let g:loaded_claudecode = 1

" Save user's cpoptions and set to Vim defaults
let s:save_cpo = &cpoptions
set cpoptions&vim

" Initialize plugin on first use
let s:initialized = 0

function! s:initialize()
  if s:initialized
    return 1
  endif
  
  " Load required modules
  runtime autoload/claudecode/deps.vim
  runtime autoload/claudecode/config.vim
  runtime autoload/claudecode/terminal.vim
  runtime autoload/claudecode/context.vim
  
  " Validate configuration
  if !claudecode#config#validate()
    return 0
  endif
  
  " Check dependencies (but don't fail completely)
  call claudecode#deps#validate_all()
  
  let s:initialized = 1
  return 1
endfunction

function! s:ClaudeCode(...)
  " Command function for :ClaudeCode
  if !s:initialize()
    return
  endif
  
  " Check if Claude CLI is available
  if !claudecode#deps#check_claude_cli()
    echohl ErrorMsg
    echo "claudecode.vim: Claude CLI not found. Please install Claude CLI and ensure it's in your PATH."
    echohl None
    return
  endif
  
  " Open or focus Claude terminal with arguments
  let l:args = a:000
  if !claudecode#terminal#open(l:args)
    echohl ErrorMsg
    echo "claudecode.vim: Failed to open Claude terminal"
    echohl None
  endif
endfunction

function! s:ClaudeCodeQuit()
  " Command function for :ClaudeCodeQuit
  if !s:initialize()
    return
  endif
  
  if claudecode#terminal#close()
    echo "Claude terminal closed"
  else
    echo "No Claude terminal to close"
  endif
endfunction

function! ClaudeCodeSendSelection() range
  " Function to send visual selection to Claude
  if !s:initialize()
    return
  endif
  
  " Check if Claude CLI is available
  if !claudecode#deps#check_claude_cli()
    echohl ErrorMsg
    echo "claudecode.vim: Claude CLI not found. Please install Claude CLI and ensure it's in your PATH."
    echohl None
    return
  endif
  
  " Ensure terminal is open
  if !claudecode#terminal#exists()
    call s:ClaudeCode()
    " Wait a moment for terminal to initialize
    sleep 500m
  endif
  
  " Get selection context
  let l:context = claudecode#context#prepare_selection_for_claude()
  
  " Send to terminal
  if claudecode#terminal#send(l:context)
    echo "Selection sent to Claude"
  else
    echohl ErrorMsg
    echo "claudecode.vim: Failed to send selection to Claude"
    echohl None
  endif
endfunction

function! ClaudeCodeSendBuffer()
  " Function to send current buffer to Claude
  if !s:initialize()
    return
  endif
  
  " Check if Claude CLI is available
  if !claudecode#deps#check_claude_cli()
    echohl ErrorMsg
    echo "claudecode.vim: Claude CLI not found. Please install Claude CLI and ensure it's in your PATH."
    echohl None
    return
  endif
  
  " Ensure terminal is open
  if !claudecode#terminal#exists()
    call s:ClaudeCode()
    " Wait a moment for terminal to initialize
    sleep 500m
  endif
  
  " Get buffer context
  let l:context = claudecode#context#prepare_buffer_for_claude()
  
  " Send to terminal
  if claudecode#terminal#send(l:context)
    echo "Buffer sent to Claude"
  else
    echohl ErrorMsg
    echo "claudecode.vim: Failed to send buffer to Claude"
    echohl None
  endif
endfunction

" Define commands
command! -nargs=* ClaudeCode call s:ClaudeCode(<f-args>)
command! ClaudeCodeQuit call s:ClaudeCodeQuit()

" Define functions that can be called by users
" (These are already defined above as global functions)

" Plugin information
let g:claudecode_version = '1.0.0'

" Restore user's cpoptions
let &cpoptions = s:save_cpo
unlet s:save_cpo

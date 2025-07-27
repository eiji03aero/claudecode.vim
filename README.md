# claudecode.vim

Yeah, everyone left vim for neovim... What can I say?

A Vim plugin that integrates Claude Code CLI with Vim, providing seamless interaction between the editor and Claude's AI capabilities.

Heavily inspired by: https://github.com/coder/claudecode.nvim

Pretty much intended for personal use.

## Todo
### Backlog
- [ ] implement diff feature
- [ ] implement auto reload buffer feature

### Done

## Features

- **Terminal Integration**: Launch Claude Code CLI in a split terminal within Vim
- **Context Sharing**: Send selected text or entire buffers to Claude with file context
- **Diff Viewing**: Automatic integration with vim-fugitive for viewing Claude-generated diffs
- **Smart Terminal Management**: Reuse existing Claude sessions and handle crashes gracefully

## Requirements

- **Vim
- **Claude Code CLI** installed and available in PATH
- **vim-fugitive** plugin for diff functionality

## Installation

Using vim-plug:
```vim
Plug 'tpope/vim-fugitive'
Plug 'eiji03aero/claudecode.vim'
```

Using Vundle:
```vim
Plugin 'tpope/vim-fugitive'
Plugin 'eiji03aero/claudecode.vim'
```

## Commands

### `:ClaudeCode [args]`
Launch Claude Code CLI in a terminal split. Accepts any arguments that would be passed to the CLI.

Examples:
- `:ClaudeCode` - Start Claude in interactive mode
- `:ClaudeCode --resume` - Resume previous session
- `:ClaudeCode "help me debug this"` - Start with a specific prompt

### `:ClaudeCodeQuit`
Close the Claude terminal and terminate the CLI session.

## Functions

### `ClaudeCodeSendSelection()`
Send the currently selected text to Claude with filename and line number context.
- Use in visual mode
- Automatically formats context as `@filename.ext#L20-25`
- Switches focus to Claude terminal after sending

### `ClaudeCodeSendBuffer()`
Send the entire current buffer to Claude using @ notation.
- Use in normal mode
- Formats context as `@filename.ext` (relative path)
- Switches focus to Claude terminal after sending

## Configuration

### Terminal Position
```vim
let g:claudecode_terminal_position = "right"  " or "bottom"
```

### Terminal Size
```vim
let g:claudecode_terminal_width = 40   " when position is "right"
let g:claudecode_terminal_height = 40  " when position is "bottom"
```

## Usage Examples

```vim
" Send current selection to Claude
vnoremap <leader>cs :call ClaudeCodeSendSelection()<CR>

" Send entire buffer to Claude
nnoremap <leader>cb :call ClaudeCodeSendBuffer()<CR>

" Quick Claude launch
nnoremap <leader>cc :ClaudeCode<CR>
```

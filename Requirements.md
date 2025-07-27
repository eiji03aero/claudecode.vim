# claudecode.vim Requirements

## Overview
claudecode.vim is a Vim plugin that integrates Claude Code CLI with Vim, providing seamless interaction between the editor and Claude's AI capabilities.

## Core Purpose
- Integrate Claude Code with Vim (not Neovim)
- Enable real-time context sharing between Vim and Claude
- Provide terminal-based Claude interaction within Vim
- Support Claude's file operations and diff viewing

## Commands

### :ClaudeCode
- **Purpose**: Launch Claude Code CLI in a split terminal
- **Behavior**: 
  - Opens Claude Code CLI in a terminal split
  - Reuses existing terminal if Claude Code is already running
  - Accepts arguments that are passed directly to Claude CLI
  - Examples: `:ClaudeCode`, `:ClaudeCode --resume`, `:ClaudeCode "help me debug this"`

### :ClaudeCodeQuit
- **Purpose**: Close/quit the Claude terminal
- **Behavior**: Terminates the Claude Code CLI session and closes the terminal split

## Functions

### ClaudeCodeSendSelection()
- **Purpose**: Send selected text to Claude with filename and line number context
- **Usage**: Call in visual mode to send currently selected text
- **Context Format**: `@filename.ext#L20-25` followed by the selected content
- **Behavior**: Automatically switches focus to Claude terminal after sending

### ClaudeCodeSendBuffer()
- **Purpose**: Send current buffer to Claude using @ notation with file path
- **Usage**: Call in normal mode to send entire current buffer
- **Context Format**: `@filename.ext` (relative path from working directory)
- **Behavior**: Automatically switches focus to Claude terminal after sending

## Configuration Variables

### g:claudecode_terminal_position
- **Type**: String
- **Values**: `"bottom"` or `"right"`
- **Default**: `"right"`
- **Description**: Controls where the Claude terminal split appears

### g:claudecode_terminal_width
- **Type**: Number
- **Default**: 40
- **Description**: Width in characters when terminal position is "right"

### g:claudecode_terminal_height
- **Type**: Number
- **Default**: 40
- **Description**: Height in characters when terminal position is "bottom"

## Dependencies

### Required
- **Claude Code CLI**: Must be installed and available in PATH
- **tpope/vim-fugitive**: Required for diff functionality

### Validation
- Plugin must validate Claude Code CLI availability before use
- Plugin must validate vim-fugitive availability before enabling diff features
- Show error messages in Vim console if dependencies are missing

## Features

### Context Sharing
- Send selected text or entire buffer to Claude
- Use relative file paths from working directory
- Automatic context formatting with line numbers for selections

### Diff Integration
- Automatically detect when Claude Code shows diffs
- Open vim-fugitive diff buffer in new tab
- No manual commands required for diff viewing

### Terminal Management
- Terminal is not persistent across Vim sessions
- Automatically restart Claude CLI if process crashes
- Reuse existing terminal session when possible

## Error Handling
- Display error messages in Vim console for missing dependencies
- Handle Claude CLI crashes with automatic restart on next use
- Validate all dependencies before enabling features

## Limitations
- Vim only (no Neovim support required)
- No language-specific features
- No authentication requirements
- No default key mappings provided
- No visual feedback for context sending
- No customizable leader key mapping prefix

## Implementation policy
- Use Lua as a main language

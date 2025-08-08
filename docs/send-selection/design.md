# Send Selection Feature Implementation Plan

## Overview
Implement functionality to send file paths and selections to Claude Code terminal, as specified in the requirements document.

## Features to Implement

### 1. Send Buffer Path (`ClaudeCodeSendBuffer`)
- Send relative path like `@plugin/claudecode.vim`
- Works from any buffer

### 2. Send Selection with Line Numbers (`ClaudeCodeSendSelection`)
- Send relative path with line numbers like `@plugin/claudecode.vim line 120`
- Include selected text from visual mode
- Works in visual mode

## Implementation Plan

### Phase 1: Core Utilities
1. **Create selection module** (`lua/claudecode/selection.lua`)
   - Get current buffer's relative path
   - Get visual selection text and line numbers
   - Format output text for Claude Code

### Phase 2: VimScript Bridge Functions
1. **Update autoload functions** (`autoload/claudecode.vim`)
   - Implement `claudecode#send_selection()` (lines 100-102)
   - Implement `claudecode#send_buffer()` (lines 104-106)
   - Bridge to Lua implementation

### Phase 3: Lua Implementation
1. **Add functions to main module** (`lua/claudecode/init.lua`)
   - `send_selection()` - handle visual mode selection
   - `send_buffer()` - handle current buffer path
   - Integration with existing terminal.send_text()

### Phase 4: Testing & Integration
1. **Test both commands work correctly**
2. **Ensure compatibility with existing terminal functionality**

## Technical Details

### File Path Handling
- Use `vim_compat.getcwd()` and `vim_compat.buf_get_name()` 
- Calculate relative paths using `vim_compat.fnamemodify()`

### Visual Selection
- Use `vim_compat.getpos()` for selection boundaries
- Extract selected text using `vim_compat.getline()`
- Support both line-wise and character-wise selections

### Terminal Integration
- Leverage existing `terminal.send_text()` function
- Ensure terminal is running before sending

This plan extends the existing architecture without breaking changes, following the project's Vim compatibility requirements.
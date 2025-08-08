# Send Selection Usage Guide

## Commands

### `:ClaudeCodeSendBuffer`
Sends the current buffer's relative path to Claude Code terminal.

**Example output:** `@plugin/claudecode.vim`

**Usage:**
1. Open any file in Vim
2. Run `:ClaudeCodeSendBuffer`
3. The relative path will be sent to the Claude Code terminal

### `:ClaudeCodeSendSelection`  
Sends the current buffer's path with line numbers and selected text to Claude Code terminal.

**Example output:**
```
@plugin/claudecode.vim line 25
selected text content here
```

**Usage:**
1. Open any file in Vim
2. Enter visual mode (`v`, `V`, or `Ctrl+v`)
3. Select the text you want to send
4. Run `:ClaudeCodeSendSelection`
5. The path, line numbers, and selected text will be sent to the Claude Code terminal

## Prerequisites

- Claude Code terminal must be running (`:ClaudeCode`)
- For selection command, you must have an active visual selection

## Error Messages

- "Claude Code terminal is not running" - Start the terminal first with `:ClaudeCode`
- "Buffer has no name" - Save the buffer first or give it a name
- "No visual selection found" - Make a visual selection before using the selection command
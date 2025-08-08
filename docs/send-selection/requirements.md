# Requirements
- User can send relative path to opened buffer to claude code
    - example
        - if opened buffer is in a path `./plugin/claudecode.vim` which is relative to the directory in which vim is opened
        - the plugin should append a text like `@plugin/claudecode.vim` to claude code terminal

- User can send relative path to opened buffer and line number to claude code
    - example
        - if opened buffer is in a path `./plugin/claudecode.vim` which is relative to the directory in which vim is opened and cursor is on line 120
        - the plugin should append a text like `@plugin/claudecode.vim line 120` with text selected by visual mode to claude code terminal
    - this is intended to be used in visual mode

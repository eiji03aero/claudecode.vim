# claudecode.vim Project Memory

## Development Guidelines

### Vim Compatibility
- This project targets standard Vim only - Neovim support is not needed
- Do not use Neovim-specific APIs (vim.api.nvim_* functions)
- All code must work with standard Vim
- Use vim_compat.lua for cross-platform vim command abstractions

## Architecture

### Error Handling
- Uses vim_compat.lua for vim command compatibility
- error.lua handles error reporting with proper vim highlighting

## Code Organization
- lua/claudecode/ - Main Lua modules
- vim_compat.lua - Vim command compatibility layer

package = "claudecode"
version = "dev-1"
source = {
   url = "git+https://github.com/yourusername/claudecode.vim.git"
}
description = {
   summary = "Claude Code integration for Vim",
   detailed = [[
      A Vim plugin that integrates with Claude Code, providing 
      websocket-based MCP server functionality with Lua tools.
   ]],
   homepage = "https://github.com/yourusername/claudecode.vim",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "dkjson >= 2.5"
}
build = {
   type = "builtin",
   modules = {
      ["claudecode.init"] = "lua/claudecode/init.lua",
      ["claudecode.config"] = "lua/claudecode/config.lua",
      ["claudecode.deps"] = "lua/claudecode/deps.lua",
      ["claudecode.logger"] = "lua/claudecode/logger.lua", 
      ["claudecode.terminal"] = "lua/claudecode/terminal.lua",
      ["claudecode.utils"] = "lua/claudecode/utils.lua",
      ["claudecode.vim_compat"] = "lua/claudecode/vim_compat.lua",
      ["claudecode.mcp"] = "lua/claudecode/mcp/init.lua",
      ["claudecode.mcp.server"] = "lua/claudecode/mcp/server/init.lua",
      ["claudecode.mcp.tools"] = "lua/claudecode/mcp/tools/init.lua",
      ["claudecode.mcp.tools.open_file"] = "lua/claudecode/mcp/tools/open_file.lua",
      ["claudecode.mcp.tools.close_all_diff_tabs"] = "lua/claudecode/mcp/tools/close_all_diff_tabs.lua",
      ["claudecode.mcp.tools.get_diagnostics"] = "lua/claudecode/mcp/tools/get_diagnostics.lua"
   },
}

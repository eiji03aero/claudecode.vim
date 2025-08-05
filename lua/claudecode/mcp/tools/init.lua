local logger = require("claudecode.logger")
local M = {}

M.tools = {}

function M.setup()
  M.register_all()
end

function M.get_tool_list()
  local tool_list = {}

  for name, tool_data in pairs(M.tools) do
    if tool_data.schema then
      local tool_def = {
        name = name,
        description = tool_data.schema.description,
        inputSchema = tool_data.schema.inputSchema,
      }
      table.insert(tool_list, tool_def)
    end
  end

  return tool_list
end

function M.register_all()
  M.register(require("claudecode.mcp.tools.open_file"))
  M.register(require("claudecode.mcp.tools.close_all_diff_tabs"))
  M.register(require("claudecode.mcp.tools.get_diagnostics"))
end

function M.register(tool_module)
  M.tools[tool_module.name] = {
    handler = tool_module.handler,
    schema = tool_module.schema, -- Will be nil if not defined in the module
    requires_coroutine = tool_module.requires_coroutine, -- Will be nil if not defined in the module
  }
end

function M.handle_invoke(client, params) -- client needed for blocking tools
  local tool_name = params.name
  local input = params.arguments

  local tool_data = M.tools[tool_name]
  if not tool_data then
    logger.debug("tool not implemented: ", tool_name)
    return { skipped = true }
  end

  local pcall_results = { pcall(tool_data.handler, input) }

  local handler_return_val1 = pcall_results[2]

  return { result = handler_return_val1, skipped = false }
end

return M

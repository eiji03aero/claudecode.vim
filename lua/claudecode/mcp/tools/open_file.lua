local vim_compat = require('claudecode.vim_compat')

local schema = {
  description = "Opens a file in the editor with optional selection by line numbers or text patterns",
  inputSchema = {
    type = "object",
    properties = {
      filePath = {
        type = "string",
        description = "Path to the file to open",
      },
      startLine = {
        type = "integer",
        description = "Optional: Line number to start selection",
      },
      endLine = {
        type = "integer",
        description = "Optional: Line number to end selection",
      },
      startText = {
        type = "string",
        description = "Optional: Text pattern to start selection",
      },
      endText = {
        type = "string",
        description = "Optional: Text pattern to end selection",
      },
    },
    required = { "filePath" },
    additionalProperties = false,
    ["$schema"] = "http://json-schema.org/draft-07/schema#",
  },
}

local function handler(args)
  local file_path = args.filePath
  
  if not file_path or file_path == "" then
    error({
      message = "filePath is required"
    })
  end
  
  -- Use vim edit command to open the file
  local success, err = pcall(function()
    vim_compat.cmd('edit ' .. vim.fn.fnameescape(file_path))
  end)
  
  if not success then
    error({
      message = "Failed to open file: " .. tostring(err)
    })
  end
  
  -- Handle optional line selection
  if args.startLine then
    pcall(function()
      vim_compat.cmd(tostring(args.startLine))
    end)
  end
  
  -- Handle optional text pattern selection
  if args.startText then
    pcall(function()
      vim_compat.cmd('/' .. vim.fn.escape(args.startText, '/\\'))
    end)
  end
  
  return {
    message = "File opened: " .. file_path
  }
end

return {
  name = "openFile",
  schema = schema,
  handler = handler
}

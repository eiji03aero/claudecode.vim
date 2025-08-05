local schema = {
  description = "Get language diagnostics (errors, warnings) from the editor",
  inputSchema = {
    type = "object",
    properties = {
      uri = {
        type = "string",
        description = "Optional file URI to get diagnostics for. If not provided, gets diagnostics for all open files.",
      },
    },
    additionalProperties = false,
    ["$schema"] = "http://json-schema.org/draft-07/schema#",
  },
}

local function handler(params)
  return {
    content = {},
  }
end

return {
  name = "getDiagnostics",
  schema = schema,
  handler = handler,
}

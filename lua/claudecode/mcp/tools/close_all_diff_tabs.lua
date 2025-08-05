local schema = {
  description = "Close all the tab/buffer",
  inputSchema = {
    type = "object",
    additionalProperties = false,
    ["$schema"] = "http://json-schema.org/draft-07/schema#",
  },
}

local function handler(params)
  return { message = "Closed all the diff tabs" }
end

return {
  name = "closeAllDiffTabs",
  schema = schema,
  handler = handler,
}

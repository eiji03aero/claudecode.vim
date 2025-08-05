local config = {}

config.defaults = {
    terminal_position = "rightbelow",
    terminal_width = 80,
    terminal_height = 40
}

local function validate_terminal_position(pos)
    return pos == "rightbelow"
end

local function validate_terminal_size(size)
    return type(size) == "number" and size > 0 and size <= 200
end

function config.get_terminal_position()
    return vim.g.claudecode_terminal_position or config.defaults.terminal_position
end

function config.get_terminal_width()
    return vim.g.claudecode_terminal_width or config.defaults.terminal_width
end

function config.get_terminal_height()
    return vim.g.claudecode_terminal_height or config.defaults.terminal_height
end

function config.validate()
    local pos = config.get_terminal_position()
    if not validate_terminal_position(pos) then
        error("Invalid terminal position: " .. tostring(pos))
    end
    
    local width = config.get_terminal_width()
    if not validate_terminal_size(width) then
        error("Invalid terminal width: " .. tostring(width))
    end
    
    local height = config.get_terminal_height()
    if not validate_terminal_size(height) then
        error("Invalid terminal height: " .. tostring(height))
    end
end

function config.set_defaults()
    vim.g.claudecode_terminal_position = vim.g.claudecode_terminal_position or config.defaults.terminal_position
    vim.g.claudecode_terminal_width = vim.g.claudecode_terminal_width or config.defaults.terminal_width
    vim.g.claudecode_terminal_height = vim.g.claudecode_terminal_height or config.defaults.terminal_height
end

return config

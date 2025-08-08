local M = {}
local utils = require('claudecode.utils')

local log_file_path = nil

function M.setup(pid)
    local timestamp = os.date("%Y%m%d%H%M")
    local log_dir = "/tmp/claudecode-vim"
    
    -- Check if directory exists before creating it
    local check_cmd = string.format('test -d "%s"', log_dir)
    local result = os.execute(check_cmd)
    local dir_exists = false
    
    if type(result) == "boolean" then
        -- Lua 5.2+
        dir_exists = result
    else
        -- Lua 5.1
        dir_exists = (result == 0)
    end
    
    -- Only create directory if it doesn't exist
    if not dir_exists then
        utils.mkdir(log_dir, "p")
    end
    
    log_file_path = log_dir .. "/" .. timestamp .. "-" .. pid .. ".log"
    
    -- Check if log file already exists
    local file_check = io.open(log_file_path, "r")
    if file_check then
        -- File exists, just close it and don't create new one
        file_check:close()
    else
        -- File doesn't exist, create it
        local file = io.open(log_file_path, "w")
        if file then
            file:close()
        end
    end
end

function M.debug(message)
    if not log_file_path then
        return
    end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = "[DEBUG] [" .. timestamp .. "] " .. message .. "\n"
    
    local file = io.open(log_file_path, "a")
    if file then
        file:write(log_entry)
        file:close()
    end
end

function M.error(message)
    local vim_compat = require("claudecode.vim_compat")

    if not log_file_path then
        return
    end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = "[ERROR] [" .. timestamp .. "] " .. message .. "\n"
    
    local file = io.open(log_file_path, "a")
    if file then
        file:write(log_entry)
        file:close()
    end

    vim_compat.echo(log_entry, "ErrorMsg")
end

function M.open_log_file()
    local vim_compat = require("claudecode.vim_compat")

    if not log_file_path then
        vim_compat.echo("Log file not initialized. Call setup() first.", "ErrorMsg")
        return
    end
    
    vim.command("edit " .. log_file_path)
end

return M

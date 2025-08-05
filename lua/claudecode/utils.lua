local utils = {}

-- Load dkjson directly
local dkjson = require("dkjson")

-- JSON encode wrapper function
function utils.json_encode(obj)
    return dkjson.encode(obj)
end

-- JSON decode wrapper function
function utils.json_decode(str)
    return dkjson.decode(str)
end


-- Create directory using direct os.execute (no vim.eval dependency)
function utils.mkdir(path, flags)
    if not path or path == "" then
        return false
    end
    
    -- Build mkdir command based on flags
    local cmd
    if flags == "p" or flags == "-p" then
        cmd = string.format('mkdir -p "%s"', path:gsub('"', '\\"'))
    else
        cmd = string.format('mkdir "%s"', path:gsub('"', '\\"'))
    end
    
    -- Execute command directly
    local result = os.execute(cmd)
    
    -- Check result based on Lua version
    if type(result) == "boolean" then
        -- Lua 5.2+
        return result
    else
        -- Lua 5.1
        return result == 0
    end
end

-- Get plugin directory absolute path via vim.eval
function utils.get_plugin_directory()
    -- Call the Vim function that returns the plugin root directory
    local result = vim.eval('claudecode#get_plugin_directory()')
    if not result or result == "" then
        error("Failed to get plugin directory")
    end
    -- Remove trailing slash if present
    return result:gsub("/$", "")
end

return utils

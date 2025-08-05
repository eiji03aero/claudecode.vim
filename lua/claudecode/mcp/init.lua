local mcp_server = {}
local vim_compat = require('claudecode.vim_compat')
local utils = require('claudecode.utils')
local logger = require('claudecode.logger')

-- Global state for the MCP server
mcp_server._server_info = nil
mcp_server._server_process = nil

function mcp_server.find_available_port()
    -- Start from port 8000 and find first available port
    for port = 8000, 8999 do
        -- Use lsof to check if port is in use (more reliable than nc)
        local check_cmd = string.format("lsof -ti :%d 2>/dev/null", port)
        local result = vim_compat.system(check_cmd)
        -- If lsof returns empty, port is available
        if result:match("^%s*$") then
            return port
        end
    end
    return nil
end

function mcp_server.generate_uuid()
    -- Simple UUID v4 generation for Vim compatibility
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

function mcp_server.get_workspace_folder()
    return vim_compat.getcwd()
end

function mcp_server.get_claude_dir()
    local success, home = pcall(vim_compat.expand, '$HOME')
    if not success or not home or home == '' then
        -- Fallback: try environment variable directly
        home = os.getenv('HOME') or '/tmp'
    end
    return home .. '/.claude/ide'
end

function mcp_server.ensure_claude_dir()
    local claude_dir = mcp_server.get_claude_dir()
    local check_cmd = string.format('test -d "%s"', claude_dir)
    local result = vim_compat.system(check_cmd)

    if result:match("^%s*$") then
        -- Directory exists
        return true
    else
        -- Create directory
        local mkdir_cmd = string.format('mkdir -p "%s"', claude_dir)
        local mkdir_result = vim_compat.system(mkdir_cmd)
        return mkdir_result:match("^%s*$")
    end
end

function mcp_server.create_lock_file(port, auth_token)
    if not mcp_server.ensure_claude_dir() then
        logger.error("Failed to create ~/.claude/ide directory")
        return false
    end

    local lock_file_path = string.format("%s/%d.lock", mcp_server.get_claude_dir(), port)
    local workspace_folder = mcp_server.get_workspace_folder()

    local lock_data = {
        pid = tostring(vim.eval('getpid()')),
        workspaceFolders = {workspace_folder},
        ideName = "Vim",
        transport = "ws",
        authToken = auth_token
    }
    local lock_content = utils.json_encode(lock_data)

    -- Write lock file using Lua IO
    local file = io.open(lock_file_path, "w")
    if not file then
        logger.error("Failed to create lock file: " .. lock_file_path)
        return nil
    end

    file:write(lock_content)
    file:close()

    return lock_file_path
end

function mcp_server.remove_lock_file(port)
    if not port then
        return false
    end

    local lock_file_path = string.format("%s/%d.lock", mcp_server.get_claude_dir(), port)
    local rm_cmd = string.format('rm -f "%s"', lock_file_path)
    local result = vim_compat.system(rm_cmd)
    return result:match("^%s*$")
end

function mcp_server.get_script_path()
    -- Get plugin directory absolute path using utils function
    local plugin_dir = utils.get_plugin_directory()
    logger.debug("Plugin directory: " .. tostring(plugin_dir))

    -- Concatenate with lua/mcp/server/init.lua
    return plugin_dir .. "/lua/claudecode/mcp/server/init.lua"
end

function mcp_server.start_mcp_server_job(port, auth_token, parent_pid)
    logger.debug("start_mcp_server_job")
    -- Get the path to the websocket server script
    local script_file = mcp_server.get_script_path()

    -- Check if script file exists
    local check_cmd = string.format('test -f "%s"', script_file)
    local result = vim_compat.system(check_cmd)
    if not result:match("^%s*$") then
        logger.error("WebSocket server script not found: " .. script_file)
        return nil
    end

    -- Prepare the command arguments
    local cmd_args = {"lua", script_file, tostring(port), auth_token, tostring(parent_pid)}

    logger.debug("Starting WebSocket server with job_start: " .. table.concat(cmd_args, " "))

    -- Start the server using vim_compat.jobstart
    local job_opts = {
        on_stdout = function(job_id, data, event)
            logger.debug("on_stdout called - job_id: " .. tostring(job_id) .. ", event: " .. tostring(event))
            logger.debug("on_stdout data type: " .. type(data) .. ", data: " .. vim_compat.inspect(data))
            if data and #data > 0 then
                for i, line in ipairs(data) do
                    logger.debug("Server stdout[" .. i .. "]: " .. tostring(line))
                end
            else
                logger.debug("on_stdout: no data or empty data")
            end
        end,
        on_stderr = function(job_id, data, event)
            logger.debug("on_stderr called - job_id: " .. tostring(job_id) .. ", event: " .. tostring(event))
            logger.debug("on_stderr data type: " .. type(data) .. ", data: " .. vim_compat.inspect(data))
            if data and #data > 0 then
                for i, line in ipairs(data) do
                    logger.debug("Server stderr[" .. i .. "]: " .. tostring(line))
                end
            else
                logger.debug("on_stderr: no data or empty data")
            end
        end,
        on_exit = function(job_id, exit_code, event)
            logger.debug("WebSocket server process exited with code: " .. tostring(exit_code))
            mcp_server._server_info = nil
        end
    }

    vim_compat.jobstart(cmd_args, job_opts)
    logger.debug("WebSocket server job started")
end


function mcp_server.start_mcp_server(port, auth_token)
        logger.debug("start_mcp_server")
    -- Get current Vim process PID
    local vim_pid = vim_compat.getpid()

    -- Start the server using job_start
    mcp_server.start_mcp_server_job(port, auth_token, vim_pid)
end

function mcp_server.start()
    logger.debug("just got started")
    if mcp_server._server_info then
        return true
    end

    -- Clean up any existing MCP server processes
    local cleanup_cmd = "pkill -f 'lua.*mcp' 2>/dev/null || true"
    vim_compat.system(cleanup_cmd)

    -- Find available port
    local port = mcp_server.find_available_port()
    if not port then
        logger.error("No available ports found")
        return false
    end

    -- Generate auth token
    local auth_token = mcp_server.generate_uuid()

    logger.debug("creating lock file")
    -- Create lock file
    local lock_file_path = mcp_server.create_lock_file(port, auth_token)
    if not lock_file_path then
        return false
    end

    logger.debug("going to starting websocket server")
    -- Start WebSocket server
    mcp_server.start_mcp_server(port, auth_token)

    -- Store server info
    mcp_server._server_info = {
        port = port,
        auth_token = auth_token,
        lock_file_path = lock_file_path,
    }

    return true
end

function mcp_server.stop()
    if not mcp_server._server_info then
        return false
    end

    mcp_server.cleanup()
    return true
end

function mcp_server.cleanup()
    if not mcp_server._server_info then
        return
    end

    local info = mcp_server._server_info

    -- Stop server job
        vim_compat.jobstop()
        if info.port then
            local kill_cmd = string.format("pkill -f 'lua.*mcp.*%d'", info.port)
            vim_compat.system(kill_cmd)
        end

    -- Remove lock file
    if info.port then
        mcp_server.remove_lock_file(info.port)
    end

    mcp_server._server_info = nil
end

function mcp_server.is_running()
    return mcp_server._server_info ~= nil
end

function mcp_server.get_status()
    if not mcp_server._server_info then
        return nil
    end

    return {
        port = mcp_server._server_info.port,
        auth_token = mcp_server._server_info.auth_token,
        lock_file = mcp_server._server_info.lock_file_path
    }
end

return mcp_server

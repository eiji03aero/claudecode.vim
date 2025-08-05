local claudecode = {}
local vim_compat = require('claudecode.vim_compat')

local config = require('claudecode.config')
local deps = require('claudecode.deps')
local terminal = require('claudecode.terminal')
local mcp = require('claudecode.mcp')
local logger = require('claudecode.logger')

logger.setup(vim_compat.getpid())

function claudecode.launch(args)
    config.set_defaults()

    local success, err = pcall(config.validate)
    if not success then
        logger.error("Configuration error: " .. tostring(err))
        return false
    end

    if not deps.check_claude_cli() then
        logger.error("Claude CLI not available")
        return false
    end

    -- Start MCP websocket server if not already running
    if not mcp.is_running() then
        local mcp_success = mcp.start()
        if not mcp_success then
            logger.error("Failed to start MCP server")
            return false
        end
    else
        vim_compat.echo("MCP server already running", "Comment")
    end

    local existing_terminal = terminal.find_existing()
    if existing_terminal then
        terminal.focus()
        return true
    end

    local success, job_id = pcall(terminal.create, args or "")
    logger.debug("terminal.create done")
    if not success then
        logger.error("Failed to create terminal: " .. tostring(job_id))
        return false
    end

    logger.debug("finishing claudecode.launch")
    return true
end

function claudecode.quit()
    terminal.close()
    mcp.stop()
end

function claudecode.is_available()
    return deps.check_claude_cli()
end

function claudecode.get_terminal_id()
    return terminal.get_buffer_id()
end

function claudecode.is_running()
    return terminal.is_running()
end

function claudecode.get_status()
    local deps_status = deps.check_all()
    return {
        running = terminal.is_running(),
        terminal_id = terminal.get_buffer_id(),
        dependencies = deps_status,
        config = {
            position = config.get_terminal_position(),
            width = config.get_terminal_width(),
            height = config.get_terminal_height()
        },
        mcp_server = mcp.get_status()
    }
end

return claudecode

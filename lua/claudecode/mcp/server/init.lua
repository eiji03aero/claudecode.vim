#!/usr/bin/env lua

-- WebSocket MCP Server using lua-http
local http_server = require "http.server"
local http_headers = require "http.headers"
local websocket = require "http.websocket"

-- Get command line arguments
local port = tonumber(arg[1]) or 8080
local auth_token = arg[2] or "default-token"
local parent_pid = arg[3] -- Optional parent process PID for monitoring

-- Add the parent directory to package.path to find claudecode modules
local script_dir = debug.getinfo(1, "S").source:match("@(.*)/")
if script_dir then
    local parent_dir = script_dir:gsub("/mcp/server$", "")
    -- Go up one more level to find the lua directory that contains claudecode
    local lua_dir = parent_dir:gsub("/claudecode$", "")
    -- Add the lua directory to package.path so claudecode.mcp.tools can be found
    package.path = lua_dir .. "/?.lua;" .. lua_dir .. "/?/init.lua;" .. package.path
end

-- Load logger module
local logger_success, logger = pcall(require, "claudecode.logger")
if not logger_success then
    print("Failed to load claudecode.logger: " .. tostring(logger))
    os.exit(1)
end
logger.setup(parent_pid)

-- Load tools module
local tools_success, tools = pcall(require, "claudecode.mcp.tools")
if not tools_success then
    logger.debug("Failed to load claudecode.mcp.tools: " .. tostring(tools))
    logger.debug("Current working directory: " .. tostring(io.popen("pwd"):read("*a")))
    logger.debug("Script directory: " .. tostring(script_dir))
    os.exit(1)
end

local setup_success, setup_err = pcall(tools.setup)
if not setup_success then
    logger.debug("Failed to setup tools: " .. tostring(setup_err))
    os.exit(1)
end

-- Load utils module for JSON handling
local utils_success, utils = pcall(require, "claudecode.utils")
if not utils_success then
    logger.debug("Failed to load claudecode.utils: " .. tostring(utils))
    os.exit(1)
end

-- Use logger module for debug logging

logger.debug("Script started with args: port=" .. port .. ", auth_token=" .. auth_token .. ", parent_pid=" .. tostring(parent_pid))
logger.debug("Starting WebSocket MCP server on port " .. port)

-- Forward declaration for cleanup function
local cleanup

-- Parent process monitoring function
local function check_parent_process()
    if parent_pid and tonumber(parent_pid) then
        local pid_num = tonumber(parent_pid)
        -- Check if parent process is still running using ps command which is more reliable
        local check_cmd = string.format("ps -p %d > /dev/null 2>&1", pid_num)
        local result = os.execute(check_cmd)
        
        -- Debug: show the result for troubleshooting
        logger.debug("Parent process check: pid=" .. pid_num .. ", result=" .. tostring(result))
        
        -- In Lua 5.1, os.execute returns the exit code directly
        -- In Lua 5.2+, it returns true/false and exit code
        local process_exists = false
        if type(result) == "boolean" then
            -- Lua 5.2+
            process_exists = result
        else
            -- Lua 5.1
            process_exists = (result == 0)
        end
        
        if not process_exists then
            logger.debug("Parent process " .. parent_pid .. " no longer exists, shutting down")
            if cleanup then
                cleanup()
            else
                os.exit(0)
            end
        else
            logger.debug("Parent process " .. parent_pid .. " is still running")
        end
    end
end

logger.debug("Creating HTTP server...")

-- Check if port is already in use and clean up if needed
local function check_and_cleanup_port(port)
    -- Check if port is in use
    local check_cmd = string.format("lsof -ti :%d", port)
    local handle = io.popen(check_cmd)
    local result = handle:read("*a")
    handle:close()
    
    if result and result:match("%d+") then
        logger.debug("Port " .. port .. " is already in use by process: " .. result:gsub("\n", ", "))
        
        -- Kill existing processes on this port
        local kill_cmd = string.format("lsof -ti :%d | xargs kill -9 2>/dev/null", port)
        os.execute(kill_cmd)
        logger.debug("Killed existing processes on port " .. port)
        
        -- Wait a moment for cleanup
        os.execute("sleep 1")
        
        -- Double check
        local handle2 = io.popen(check_cmd)
        local result2 = handle2:read("*a")
        handle2:close()
        
        if result2 and result2:match("%d+") then
            logger.debug("Warning: Port " .. port .. " may still be in use")
            return false
        else
            logger.debug("Port " .. port .. " is now available")
            return true
        end
    else
        logger.debug("Port " .. port .. " is available")
        return true
    end
end

-- Clean up port before starting server
if not check_and_cleanup_port(port) then
    logger.debug("Failed to free port " .. port .. ", trying anyway...")
end

-- Try to load required modules
-- Create HTTP server
local server, server_err = http_server.listen {
        host = "127.0.0.1",
        port = port,
    onstream = function(server, stream)
        local req_headers = stream:get_headers()
        local upgrade = req_headers:get("upgrade")
        
        if upgrade and upgrade:lower() == "websocket" then
            -- WebSocket upgrade request
            logger.debug("WebSocket upgrade request received")
            
            -- Log headers for debugging
            logger.debug("Request headers:")
            for name, value in req_headers:each() do
                logger.debug("  " .. name .. ": " .. value)
            end
            
            -- Use lua-http's proper WebSocket handshake
            local ws = websocket.new_from_stream(stream, req_headers)
            if not ws then
                logger.debug("Invalid WebSocket upgrade request")
                -- Send 400 Bad Request
                local response_headers = http_headers.new()
                response_headers:append(":status", "400")
                response_headers:append("content-type", "text/plain")
                stream:write_headers(response_headers, false)
                stream:write_body_from_string("Invalid WebSocket upgrade request")
                return
            end
            
            -- Complete the WebSocket handshake
            local accept_success, accept_err = pcall(function()
                ws:accept({
                    protocols = {"mcp"}
                })
            end)
            
            if not accept_success then
                logger.debug("WebSocket handshake failed: " .. tostring(accept_err))
                return
            end
            
            logger.debug("WebSocket connection established")
            
            -- Try alternative WebSocket message handling
            logger.debug("Starting WebSocket message handling...")
            
            -- Main WebSocket message loop with timeout
            local connection_active = true
            while connection_active do                
                -- Try to receive without timeout first
                local success, data, opcode = pcall(function()
                    return ws:receive() -- No timeout
                end)
                
                logger.debug("ws:receive result - success: " .. tostring(success) .. ", data: " .. tostring(data) .. ", opcode: " .. tostring(opcode))
                
                if not success then
                    logger.debug("Error in ws:receive(): " .. tostring(data))
                    connection_active = false
                    break
                end
                
                -- Check if connection was closed
                if data == nil then
                    logger.debug("WebSocket connection closed by client")
                    connection_active = false
                    break
                end
                
                -- Check opcode values - use numeric values instead of constants
                -- TEXT=1, BINARY=2, CLOSE=8, PING=9, PONG=10
                if opcode == "text" then -- TEXT frame
                    logger.debug("Received WebSocket message: " .. data)
                    
                    -- Try to parse as MCP message
                    local msg = utils.json_decode(data)
                    if msg and msg.jsonrpc then
                        logger.debug("Parsed MCP message - method: " .. tostring(msg.method) .. ", id: " .. tostring(msg.id))
                        
                        local response = nil
                        
                        -- Handle initialize method
                        if msg.method == "initialize" then
                            logger.debug("Handling initialize request")
                            response = {
                                jsonrpc = "2.0",
                                id = msg.id,
                                result = {
                                    protocolVersion = "2024-11-05",
                                    capabilities = {
                                        logging = {_object = true},
                                        prompts = { 
                                            listChanged = true 
                                        },
                                        resources = { 
                                            subscribe = true, 
                                            listChanged = true 
                                        },
                                        tools = { 
                                            listChanged = true 
                                        }
                                    },
                                    serverInfo = {
                                        name = "claudecode-vim",
                                        version = "1.0.0"
                                    }
                                }
                            }
                        elseif msg.method == "tools/list" then
                            logger.debug("Handling tools/list request")
                            local tool_list = tools.get_tool_list()
                            logger.debug("Available tools: " .. tostring(#tool_list))
                            response = {
                                jsonrpc = "2.0",
                                id = msg.id,
                                result = {
                                    tools = tool_list
                                }
                            }
                        elseif msg.method == "tools/call" then
                            logger.debug("Handling tools/call request for tool: " .. tostring(msg.params and msg.params.name))
                            logger.debug("Full tools/call message: " .. utils.json_encode(msg))
                            logger.debug("Full tools/call message: " .. data)
                            
                            local success, result = pcall(function()
                                return tools.handle_invoke(nil, msg.params)
                            end)
                            
                            if success and not result.skipped then
                                logger.debug("Tool execution successful")
                                response = {
                                    jsonrpc = "2.0",
                                    id = msg.id,
                                    result = result.result
                                }
                            else
                                logger.debug("Tool execution failed: " .. tostring(result))
                                response = {
                                    jsonrpc = "2.0",
                                    id = msg.id,
                                    error = {
                                        code = -32603,
                                        message = "Tool execution failed",
                                        data = {
                                            error = tostring(result)
                                        }
                                    }
                                }
                            end
                        elseif msg.method == "prompts/list" then
                            logger.debug("Handling prompts/list request")
                            response = {
                                jsonrpc = "2.0",
                                id = msg.id,
                                result = {
                                    prompts = {}
                                }
                            }
                        elseif msg.method == "resources/list" then
                            logger.debug("Handling resources/list request")
                            response = {
                                jsonrpc = "2.0",
                                id = msg.id,
                                result = {
                                    resources = {}
                                }
                            }
                        elseif msg.method == "notifications/cancelled" or 
                               msg.method == "ide_connected" or 
                               msg.method == "notifications/initialized" then
                            logger.debug("Handling notification method: " .. msg.method .. " (no response needed)")
                            response = nil -- No response for notifications
                        else
                            -- Handle other methods or return method not found
                            logger.debug("Unknown method: " .. tostring(msg.method))
                            response = {
                                jsonrpc = "2.0",
                                id = msg.id,
                                error = {
                                    code = -32601,
                                    message = "Method not found",
                                    data = {
                                        method = msg.method
                                    }
                                }
                            }
                        end
                        
                        if response then
                            local response_json = utils.json_encode(response)
                            local send_success, send_err = pcall(function()
                                ws:send(response_json)
                            end)
                            if send_success then
                                logger.debug("Sent MCP response: " .. response_json)
                            else
                                logger.debug("Failed to send MCP response: " .. tostring(send_err))
                                connection_active = false
                                break
                            end
                        end
                    else
                        -- Simple echo for non-MCP messages
                        local echo_response = "Echo: " .. data
                        local send_success, send_err = pcall(function()
                            ws:send(echo_response)
                        end)
                        if send_success then
                            logger.debug("Sent echo response: " .. echo_response)
                        else
                            logger.debug("Failed to send echo response: " .. tostring(send_err))
                            connection_active = false
                            break
                        end
                    end
                elseif opcode == 9 then -- PING frame
                    logger.debug("Received ping, sending pong")
                    local pong_success, pong_err = pcall(function()
                        ws:send(data, 10) -- PONG opcode
                    end)
                    if not pong_success then
                        logger.debug("Failed to send pong: " .. tostring(pong_err))
                        connection_active = false
                        break
                    end
                elseif opcode == 8 then -- CLOSE frame
                    logger.debug("Received close frame")
                    connection_active = false
                    break
                end
            end
            
            ws:close()
            logger.debug("WebSocket connection closed")
        else
            -- Regular HTTP request - return server info
            local response_body = utils.json_encode({
                jsonrpc = "2.0",
                result = {
                    status = "ready",
                    port = port,
                    auth_token = auth_token,
                    protocol = "mcp",
                    server = "claudecode.vim",
                    transport = "ws",
                    endpoint = "ws://127.0.0.1:" .. port
                }
            })
            
            -- Send HTTP response
            local response_headers = http_headers.new()
            response_headers:append(":status", "200")
            response_headers:append("content-type", "application/json")
            response_headers:append("content-length", tostring(#response_body))
            response_headers:append("access-control-allow-origin", "*")
            response_headers:append("access-control-allow-methods", "GET, POST, OPTIONS")
            response_headers:append("access-control-allow-headers", "Content-Type, Authorization")
            response_headers:append("connection", "close")
            
            stream:write_headers(response_headers, false)
            stream:write_body_from_string(response_body)
            stream:shutdown()
            
            logger.debug("Sent HTTP response to " .. (req_headers:get(":path") or "/"))
        end
    end,
    onerror = function(server, context, op, err, errno)
        logger.debug("Server error: " .. tostring(op) .. " " .. tostring(err) .. " " .. tostring(errno))
    end
}

if not server then
    logger.debug("Failed to create server: " .. tostring(server_err))
    os.exit(1)
end

logger.debug("Server created successfully")

-- Handle signals for graceful shutdown
cleanup = function()
    logger.debug("Shutting down WebSocket MCP server...")
    if server then
        server:close()
    end
    -- Log files are now closed after each write, so no need to close here
    logger.debug("Server shutdown complete")
    os.exit(0)
end

-- Set up signal handlers for graceful shutdown
local signal_ok, signal = pcall(require, "signal")
if signal_ok then
    signal.signal(signal.SIGINT, cleanup)  -- Ctrl+C
    signal.signal(signal.SIGTERM, cleanup) -- Termination signal
    signal.signal(signal.SIGHUP, cleanup)  -- Terminal hangup
    logger.debug("Signal handlers installed")
else
    logger.debug("Signal module not available, using basic cleanup")
end

logger.debug("WebSocket MCP server starting on ws://127.0.0.1:" .. port)
logger.debug("Press Ctrl+C to stop the server")

-- Start the server event loop with parent monitoring
local success, err = pcall(function()
    logger.debug("Starting server loop...")
    
    -- If we have a parent PID, set up periodic monitoring using a timer-like approach
    if parent_pid and tonumber(parent_pid) then
        -- Check parent process once before starting
        check_parent_process()
        
        -- Start a background process to monitor parent every 30 seconds
        local monitor_cmd = string.format([[
            (while true; do
                sleep 30
                if ! ps -p %s > /dev/null 2>&1; then
                    echo "[DEBUG] Parent monitoring: Parent process %s died, killing server on port %d" >> /tmp/claudecode_mcp_%d.log
                    pkill -f "lua.*mcp.*%d"
                    break
                fi
            done) &
        ]], parent_pid, parent_pid, port, port, port)
        
        os.execute(monitor_cmd)
        logger.debug("Parent process monitoring started in background")
    end
    
    -- Run the server normally
    server:loop()
end)

if not success then
    logger.debug("Server error: " .. tostring(err))
    cleanup()
end

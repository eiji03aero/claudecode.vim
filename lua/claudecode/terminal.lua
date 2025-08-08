local terminal = {}

local config = require('claudecode.config')
local vim_compat = require('claudecode.vim_compat')
local logger = require('claudecode.logger')

terminal.state = {
    term_buffer_number = nil,
    last_activity = 0
}

function terminal.create(args)
    local split_cmd = string.format("rightbelow vertical %dsplit", config.get_terminal_width())

    vim.command(split_cmd)

    local claude_cmd = "claude --ide"
    if args and args ~= "" then
        claude_cmd = claude_cmd .. " " .. args
    end

    local term_buffer_number = vim_compat.term_start(claude_cmd, {
        on_exit = function(term_buffer_number, exit_code, event)
            terminal.handle_exit(term_buffer_number, exit_code)
        end,
        curwin = 1,
        term_kill = 'term'
    })
    vim_compat.echo("term_buffer_number in create: " .. term_buffer_number)

    terminal.state.term_buffer_number = term_buffer_number
    terminal.state.last_activity = vim_compat.localtime()

    -- Set a fixed buffer name for easy identification
    vim.command('file __ClaudeCode_Terminal__')

    return term_buffer_number
end

function terminal.find_existing()
    if terminal.state.term_buffer_number == nil then
        return nil
    end

    local term_status = vim_compat.term_getstatus(terminal.state.term_buffer_number)
    if term_status ~= "running" then
        terminal.state.term_buffer_number = nil
        return nil
    end

    return terminal.state.term_buffer_number
end

function terminal.focus()
    local buffer_number = terminal.find_existing()
    if not buffer_number then
        return false
    end

    local windows = vim_compat.win_findbuf(buffer_number)
    if #windows > 0 then
        vim_compat.set_current_win(windows[1])
        return true
    end

    return false
end

function terminal.close()
    if terminal.state.term_buffer_number then
        vim_compat.jobstop(terminal.state.term_buffer_number)
    end

    terminal.state.term_buffer_number = nil
end

function terminal.send_text(text)
    if not terminal.state.term_buffer_number then
        return false
    end

    vim_compat.term_sendkeys(terminal.state.term_buffer_number, text)
    terminal.state.last_activity = vim_compat.localtime()
    return true
end

function terminal.is_running()
    return terminal.find_existing() ~= nil
end

function terminal.get_buffer_number()
    return terminal.find_existing()
end

function terminal.restart()
    if terminal.state.term_buffer_number then
        vim_compat.jobstop(terminal.state.term_buffer_number)
    end

    terminal.state.term_buffer_number = nil

    return terminal.create("")
end

function terminal.handle_exit(term_buffer_number, exit_code)
    if exit_code ~= 0 then
        logger.error("Claude Code CLI exited with code: " .. exit_code)
    end

    terminal.state.term_buffer_number = nil
end

function terminal._handle_term_exit(callback_name, term_buffer_number, status)
    if vim_compat._exit_callbacks and vim_compat._exit_callbacks[callback_name] then
        vim_compat._exit_callbacks[callback_name](term_buffer_number, status, 'exit')
        -- Clean up - delay deletion to avoid "function in use" error
        vim_compat._exit_callbacks[callback_name] = nil
        vim.command(string.format('call timer_start(100, {-> execute("silent! delfunction %s")})', callback_name))
        vim.command(string.format('unlet! g:%s_callback', callback_name))
    end
end

return terminal

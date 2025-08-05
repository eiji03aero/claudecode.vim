local terminal = {}

local config = require('claudecode.config')
local vim_compat = require('claudecode.vim_compat')
local logger = require('claudecode.logger')

terminal.state = {
    buffer_id = nil,
    job_id = nil,
    last_activity = 0
}

function terminal.create(args)
    local split_cmd = string.format("rightbelow vertical %dsplit", config.get_terminal_width())

    vim.command(split_cmd)

    local claude_cmd = "claude --ide"
    if args and args ~= "" then
        claude_cmd = claude_cmd .. " " .. args
    end

    local job_id = vim_compat.termopen(claude_cmd, {
        on_exit = function(job_id, exit_code, event)
            terminal.handle_exit(job_id, exit_code)
        end,
        curwin = 1,
        term_kill = 'term'
    })

    terminal.state.buffer_id = vim_compat.get_current_buf()
    terminal.state.job_id = job_id
    terminal.state.last_activity = vim_compat.localtime()

    -- Set a fixed buffer name for easy identification
    vim.command('file __ClaudeCode_Terminal__')

    return job_id
end

function terminal.find_existing()
    if terminal.state.buffer_id == nil then
        return nil
    end

    if not vim_compat.buf_is_valid(terminal.state.buffer_id) then
        terminal.state.buffer_id = nil
        terminal.state.job_id = nil
        return nil
    end

    if terminal.state.job_id == nil then
        return nil
    end

    local job_status = vim_compat.jobstatus(terminal.state.job_id)
    if job_status ~= "run" then
        terminal.state.job_id = nil
        return nil
    end

    return terminal.state.buffer_id
end

function terminal.focus()
    local buffer_id = terminal.find_existing()
    if not buffer_id then
        return false
    end

    local windows = vim_compat.win_findbuf(buffer_id)
    if #windows > 0 then
        vim_compat.set_current_win(windows[1])
        return true
    end

    return false
end

function terminal.close()
    if terminal.state.job_id then
        vim_compat.jobstop(terminal.state.job_id)
    end

    if terminal.state.buffer_id and vim_compat.buf_is_valid(terminal.state.buffer_id) then
        local windows = vim_compat.win_findbuf(terminal.state.buffer_id)
        for _, win in ipairs(windows) do
            vim_compat.win_close(win, false)
        end
    end

    terminal.state.buffer_id = nil
    terminal.state.job_id = nil
end

function terminal.send_text(text)
    if not terminal.state.job_id then
        return false
    end

    vim_compat.chansend(terminal.state.job_id, text .. "\n")
    terminal.state.last_activity = vim_compat.localtime()
    return true
end

function terminal.is_running()
    return terminal.find_existing() ~= nil
end

function terminal.get_buffer_id()
    return terminal.find_existing()
end

function terminal.restart()
    if terminal.state.job_id then
        vim_compat.jobstop(terminal.state.job_id)
    end

    terminal.state.job_id = nil
    terminal.state.buffer_id = nil

    return terminal.create("")
end

function terminal.handle_exit(job_id, exit_code)
    if exit_code ~= 0 then
        logger.error("Claude Code CLI exited with code: " .. exit_code)
    end

    terminal.state.job_id = nil

    -- Close the terminal buffer using the fixed buffer name
    local closed = vim_compat.close_buffer_by_name("__ClaudeCode_Terminal__")
    if closed then
        terminal.state.buffer_id = nil
    end
end

function terminal._handle_term_exit(callback_name, job, status)
    if vim_compat._exit_callbacks and vim_compat._exit_callbacks[callback_name] then
        vim_compat._exit_callbacks[callback_name](job, status, 'exit')
        -- Clean up - delay deletion to avoid "function in use" error
        vim_compat._exit_callbacks[callback_name] = nil
        vim.command(string.format('call timer_start(100, {-> execute("silent! delfunction %s")})', callback_name))
        vim.command(string.format('unlet! g:%s_callback', callback_name))
    end
end

return terminal

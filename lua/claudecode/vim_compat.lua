local vim_compat = {}
local logger = require('claudecode.logger')

-- Vim function compatibility layer
function vim_compat.escape(text, chars)
    -- Handle newlines and other special characters properly
    text = text:gsub('\n', '\\n')
    text = text:gsub('\r', '\\r')
    text = text:gsub('\t', '\\t')
    text = text:gsub('"', '\\"')
    return text
end

function vim_compat.expand(expr)
    -- Debug: check what we're trying to expand
    local expand_cmd = string.format('expand(%q)', expr)
    local success, result = pcall(vim.eval, expand_cmd)
    if not success then
        logger.error("Failed to expand: " .. expr .. " (command: " .. expand_cmd .. ")")
        return ""
    end
    return result
end

function vim_compat.bufname(bufnr)
    return vim.eval(string.format('bufname(%d)', bufnr))
end

function vim_compat.getline(start, end_line)
    if end_line == '$' then
        return vim.eval(string.format('getline(%d, "$")', start))
    else
        return vim.eval(string.format('getline(%d, %d)', start, end_line))
    end
end

function vim_compat.getbufline(bufnr, start, end_line)
    if end_line == '$' then
        return vim.eval(string.format('getbufline(%d, %d, "$")', bufnr, start))
    else
        return vim.eval(string.format('getbufline(%d, %d, %d)', bufnr, start, end_line))
    end
end

function vim_compat.bufnr(expr)
    return vim.eval(string.format('bufnr(%q)', expr))
end

function vim_compat.bufexists(bufnr)
    return vim.eval(string.format('bufexists(%d)', bufnr)) == 1
end

function vim_compat.getcwd()
    return vim.eval('getcwd()')
end

function vim_compat.fnamemodify(fname, mods)
    return vim.eval(string.format('fnamemodify(%q, %q)', fname, mods))
end

function vim_compat.getpos(expr)
    return vim.eval(string.format('getpos(%q)', expr))
end

function vim_compat.termopen(cmd, opts)
    -- Standard Vim doesn't have termopen, use term_start instead
    local term_opts = {}

    if opts then
        if opts.curwin then
            term_opts.curwin = opts.curwin
        end
        if opts.term_kill then
            term_opts.term_kill = opts.term_kill
        end
        if opts.on_exit then
            -- Create a callback using vim function
            local callback_name = 'ClaudeCodeTermExit' .. math.random(1000, 9999)

            -- Store callback in vim variable
            vim.command(string.format('let g:%s_callback = v:null', callback_name))

            -- Create Vimscript function that calls Lua
            vim.command(string.format([[
                function! %s(job, status)
                    call luaeval('require("claudecode.terminal")._handle_term_exit(_A[1], _A[2], _A[3])', ['%s', a:job, a:status])
                endfunction
            ]], callback_name, callback_name))

            -- Store the Lua callback
            vim_compat._exit_callbacks = vim_compat._exit_callbacks or {}
            vim_compat._exit_callbacks[callback_name] = opts.on_exit

            term_opts.exit_cb = callback_name
        end
    end

    -- Build term_start command safely
    -- Build options dictionary
    vim.command("let term_opts = {}")

    for k, v in pairs(term_opts) do
        if type(v) == "string" then
            if k:match("_cb$") then
                -- This is a callback function name, reference it directly
                vim.command(string.format("let term_opts['%s'] = function('%s')", k, v))
            else
                -- Regular string value
                local escaped_v = v:gsub("'", "''")
                vim.command(string.format("let term_opts['%s'] = '%s'", k, escaped_v))
            end
        elseif type(v) == "number" then
            vim.command(string.format("let term_opts['%s'] = %d", k, v))
        else
            vim.command(string.format("let term_opts['%s'] = %s", k, tostring(v)))
        end
    end

    vim.command(string.format("let term_cmd = %q", cmd))

    -- Debug: Show what we're trying to execute
    local success, term_id = pcall(vim.eval, 'term_start(term_cmd, term_opts)')
    if not success then
        logger.error("term_start failed: " .. tostring(term_id))
        vim.command("unlet term_opts")
        vim.command("unlet term_cmd")
        return nil
    end

    vim.command("unlet term_opts")
    vim.command("unlet term_cmd")
    return term_id
end

function vim_compat.localtime()
    return vim.eval('localtime()')
end

function vim_compat.jobstatus(job_id)
    local success, result = pcall(vim.eval, string.format('job_status(%d)', job_id))
    if not success then
        return "dead"
    end
    return result or "dead"
end

function vim_compat.win_findbuf(bufnr)
    -- Standard Vim doesn't have win_findbuf, implement manually
    local windows = {}
    local success, result = pcall(vim.eval, string.format([[
        let windows = []
        for winnr in range(1, winnr('$'))
            if winbufnr(winnr) == %d
                call add(windows, winnr)
            endif
        endfor
        windows
    ]], bufnr))

    if success and result then
        return result
    else
        return {}
    end
end

function vim_compat.jobstart(cmd, opts)
    -- Use job_start for background jobs in standard Vim
    local job_opts = {}

    if opts then
        if opts.on_stdout then
            local stdout_callback_name = 'ClaudeCodeJobStdOut' .. math.random(1000, 9999)

            -- Create Vimscript function that calls Lua callback
            vim.command(string.format([[
                function! %s(channel, msg)
                    call luaeval('require("claudecode.vim_compat")._handle_job_stdout(_A[1], _A[2], _A[3])', ['%s', a:channel, a:msg])
                endfunction
            ]], stdout_callback_name, stdout_callback_name))

            -- Store the Lua callback
            vim_compat._stdout_callbacks = vim_compat._stdout_callbacks or {}
            vim_compat._stdout_callbacks[stdout_callback_name] = opts.on_stdout

            job_opts.out_cb = stdout_callback_name
        end

        if opts.on_stderr then
            local stderr_callback_name = 'ClaudeCodeJobStdErr' .. math.random(1000, 9999)

            -- Create Vimscript function that calls Lua callback
            vim.command(string.format([[
                function! %s(channel, msg)
                    call luaeval('require("claudecode.vim_compat")._handle_job_stderr(_A[1], _A[2], _A[3])', ['%s', a:channel, a:msg])
                endfunction
            ]], stderr_callback_name, stderr_callback_name))

            -- Store the Lua callback
            vim_compat._stderr_callbacks = vim_compat._stderr_callbacks or {}
            vim_compat._stderr_callbacks[stderr_callback_name] = opts.on_stderr

            job_opts.err_cb = stderr_callback_name
        end

        if opts.on_exit then
            local exit_callback_name = 'ClaudeCodeJobExit' .. math.random(1000, 9999)

            -- Create Vimscript function that calls Lua callback
            vim.command(string.format([[
                function! %s(job, status)
                    call luaeval('require("claudecode.vim_compat")._handle_job_exit(_A[1], _A[2], _A[3])', ['%s', a:job, a:status])
                endfunction
            ]], exit_callback_name, exit_callback_name))

            -- Store the Lua callback
            vim_compat._job_exit_callbacks = vim_compat._job_exit_callbacks or {}
            vim_compat._job_exit_callbacks[exit_callback_name] = opts.on_exit

            job_opts.exit_cb = exit_callback_name
        end

        -- Set mode for proper line handling
        if not opts.stdout_buffered then
            job_opts.mode = 'nl'
        end
    end

    -- Handle both string commands and array commands
    local cmd_string
    local quoted_args = {}
    for i, arg in ipairs(cmd) do
        if arg:match("%s") then
            table.insert(quoted_args, string.format('"%s"', arg))
        else
            table.insert(quoted_args, arg)
        end
    end
    cmd_string = table.concat(quoted_args, " ")

    -- Build job_start command step by step
    -- Build options dictionary
    local opts_cmd = "let job_opts = {}"
    vim.command(opts_cmd)

    for k, v in pairs(job_opts) do
        if type(v) == "string" then
            if k:match("_cb$") then
                -- This is a callback function name, reference it directly
                vim.command(string.format("let job_opts['%s'] = function('%s')", k, v))
            else
                -- Regular string value
                local escaped_v = v:gsub("'", "''")
                vim.command(string.format("let job_opts['%s'] = '%s'", k, escaped_v))
            end
        elseif type(v) == "number" then
            vim.command(string.format("let job_opts['%s'] = %d", k, v))
        else
            vim.command(string.format("let job_opts['%s'] = %s", k, tostring(v)))
        end
    end

    vim.command("let job_cmd = []")
    for i, arg in ipairs(cmd) do
        -- Check for NULL characters which can cause failures
        if arg:find('\0') then
            vim_compat.echo("Command contains NULL character, will fail", "ErrorMsg")
            vim.command("unlet job_opts")
            return nil
        end
        vim.command(string.format("call add(job_cmd, %q)", arg))
    end

    -- Use VimScript to start job and get job ID
    vim.command([[
        let g:claudecode_job = job_start(job_cmd, job_opts)
    ]])
end

function vim_compat.jobstop()
    vim.eval('job_stop(g:claudecode_job)')
end

function vim_compat.chansend(job_id, text)
    vim.eval(string.format('ch_sendraw(%d, %q)', job_id, text))
end

function vim_compat.exists(expr)
    return vim.eval(string.format('exists(%q)', expr))
end

function vim_compat.system(cmd)
    -- Escape the command safely
    local escaped_cmd = cmd:gsub('"', '\\"'):gsub("'", "''")
    local success, result = pcall(vim.eval, string.format('system("%s")', escaped_cmd))
    if not success then
        -- Fallback: try with single quotes
        success, result = pcall(vim.eval, "system('" .. cmd:gsub("'", "''") .. "')")
        if not success then
            return ""
        end
    end
    return result or ""
end


function vim_compat._handle_job_stdout(callback_name, channel, msg)
    if vim_compat._stdout_callbacks and vim_compat._stdout_callbacks[callback_name] then
        vim_compat._stdout_callbacks[callback_name](channel, {msg}, 'stdout')
    end
end

function vim_compat._handle_job_stderr(callback_name, channel, msg)
    if vim_compat._stderr_callbacks and vim_compat._stderr_callbacks[callback_name] then
        vim_compat._stderr_callbacks[callback_name](channel, {msg}, 'stderr')
    end
end

function vim_compat._handle_job_exit(callback_name, job, status)
    if vim_compat._job_exit_callbacks and vim_compat._job_exit_callbacks[callback_name] then
        vim_compat._job_exit_callbacks[callback_name](job, status, 'exit')
        -- Clean up
        vim_compat._job_exit_callbacks[callback_name] = nil
        vim.command(string.format('call timer_start(100, {-> execute("silent! delfunction %s")})', callback_name))
    end
end

function vim_compat.inspect(value)
    if type(value) == "table" then
        local items = {}
        for k, v in pairs(value) do
            if type(k) == "string" then
                table.insert(items, string.format('"%s": %s', k, vim_compat.inspect(v)))
            else
                table.insert(items, string.format('[%s]: %s', tostring(k), vim_compat.inspect(v)))
            end
        end
        return "{" .. table.concat(items, ", ") .. "}"
    elseif type(value) == "string" then
        -- Don't add quotes if the string already contains quotes
        if value:match('^".*"$') then
            return value
        else
            return string.format('"%s"', value)
        end
    else
        return tostring(value)
    end
end

function vim_compat.echo(message, highlight)
    local hl_cmd = highlight and string.format('echohl %s | ', highlight) or ''
    local clear_cmd = highlight and ' | echohl None' or ''
    vim.command(string.format('%sechomsg "%s"%s',
                            hl_cmd,
                            vim_compat.escape(message, '"'),
                            clear_cmd))
end

function vim_compat.buf_get_name(bufnr)
    bufnr = bufnr or 0
    if bufnr == 0 then
        return vim_compat.expand('%:p')
    else
        return vim_compat.bufname(bufnr)
    end
end

function vim_compat.buf_get_lines(bufnr, start, end_line, strict_indexing)
    bufnr = bufnr or 0
    if bufnr == 0 then
        if end_line == -1 then
            return vim_compat.getline(start + 1, '$')
        else
            return vim_compat.getline(start + 1, end_line)
        end
    else
        local lines = {}
        local buf_lines = vim_compat.getbufline(bufnr, 1, '$')
        if end_line == -1 then
            for i = start + 1, #buf_lines do
                table.insert(lines, buf_lines[i])
            end
        else
            for i = start + 1, math.min(end_line, #buf_lines) do
                table.insert(lines, buf_lines[i])
            end
        end
        return lines
    end
end

function vim_compat.get_current_buf()
    return vim_compat.bufnr('%')
end

function vim_compat.buf_is_valid(bufnr)
    return vim_compat.bufexists(bufnr)
end

function vim_compat.set_current_win(winnr)
    vim.command(winnr .. 'wincmd w')
end

function vim_compat.win_close(winnr, force)
    local close_cmd = force and 'quit!' or 'quit'
    vim.command(winnr .. 'wincmd w | ' .. close_cmd)
end

function vim_compat.create_autocmd(event, opts)
    local group = opts.group or ''
    local pattern = opts.pattern and string.format(' %s', opts.pattern) or ''
    local callback_name = 'ClaudeCodeAutoCmd' .. math.random(1000, 9999)

    _G[callback_name] = opts.callback

    vim.command(string.format('augroup %s', group))
    vim.command('autocmd!')
    vim.command(string.format('autocmd %s%s call v:lua.%s()', event, pattern, callback_name))
    vim.command('augroup END')
end

function vim_compat.close_buffer_by_name(buffer_name)
    local bufnr = vim_compat.bufnr(buffer_name)
    if bufnr ~= -1 and vim_compat.bufexists(bufnr) then
        vim.command(string.format('bdelete! %d', bufnr))
        return true
    end
    return false
end

function vim_compat.getpid()
    return vim.eval('getpid()')
end

function vim_compat.mkdir(path, flags)
    local success, result = pcall(vim.eval, string.format('mkdir(%q, %q)', path, flags or ""))
    return success and result or 0
end

return vim_compat

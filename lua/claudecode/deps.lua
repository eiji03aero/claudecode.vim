local deps = {}
local vim_compat = require('claudecode.vim_compat')
local logger = require('claudecode.logger')

deps.cache = {
    claude_cli = nil,
    vim_fugitive = nil,
    last_check = 0
}

function deps.check_claude_cli()
    if deps.cache.claude_cli ~= nil and 
       (vim_compat.localtime() - deps.cache.last_check) < 300 then
        return deps.cache.claude_cli
    end
    
    local result = vim_compat.system("command -v claude 2>/dev/null")
    
    local available = result and result:match("%S") ~= nil
    
    deps.cache.claude_cli = available
    deps.cache.last_check = vim_compat.localtime()
    
    return available
end

function deps.check_vim_fugitive()
    local has_fugitive = vim_compat.exists(":Git") == 2
    deps.cache.vim_fugitive = has_fugitive
    return has_fugitive
end

function deps.check_all()
    local claude_available = deps.check_claude_cli()
    local fugitive_available = deps.check_vim_fugitive()
    
    return {
        claude_cli = claude_available,
        vim_fugitive = fugitive_available,
        all_available = claude_available
    }
end

function deps.clear_cache()
    deps.cache.claude_cli = nil
    deps.cache.vim_fugitive = nil
    deps.cache.last_check = 0
end

function deps.get_cached_status()
    return {
        claude_cli = deps.cache.claude_cli,
        vim_fugitive = deps.cache.vim_fugitive,
        last_check = deps.cache.last_check
    }
end

function deps.report_missing_dependencies()
    local missing = {}
    
    if not deps.check_claude_cli() then
        table.insert(missing, "Claude Code CLI not found in PATH")
    end
    
    if not deps.check_vim_fugitive() then
        table.insert(missing, "vim-fugitive plugin not installed")
    end
    
    if #missing > 0 then
        local message = "claudecode.vim missing dependencies:\n" .. 
                       table.concat(missing, "\n")
        logger.error(message)
        return false
    end
    
    return true
end

return deps

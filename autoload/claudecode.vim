" claudecode.vim autoload functions
" Bridge between VimScript and Lua implementation

" Variables
let s:plugin_path = fnamemodify(expand('<sfile>:p:h:h'), ':p')

function! claudecode#launch(args) abort
    try
        return luaeval('require("claudecode").launch(_A)', a:args)
    catch
        echohl ErrorMsg
        echom 'claudecode.vim: ' . v:exception
        echohl None
        return 0
    endtry
endfunction

function! claudecode#quit() abort
    try
        return luaeval('require("claudecode").quit()')
    catch
        echohl ErrorMsg
        echom 'claudecode.vim: ' . v:exception
        echohl None
        return 0
    endtry
endfunction

function! claudecode#is_running() abort
    try
        return luaeval('require("claudecode").is_running()')
    catch
        return 0
    endtry
endfunction

function! claudecode#get_status() abort
    try
        return luaeval('require("claudecode").get_status()')
    catch
        return {}
    endtry
endfunction

function! claudecode#mcp_start() abort
    try
        return luaeval('require("claudecode.mcp_server").start()')
    catch
        echohl ErrorMsg
        echom 'claudecode.vim: ' . v:exception
        echohl None
        return 0
    endtry
endfunction

function! claudecode#mcp_stop() abort
    try
        return luaeval('require("claudecode.mcp_server").stop()')
    catch
        echohl ErrorMsg
        echom 'claudecode.vim: ' . v:exception
        echohl None
        return 0
    endtry
endfunction

function! claudecode#mcp_get_status() abort
    try
        return luaeval('require("claudecode.mcp_server").get_status()')
    catch
        echohl ErrorMsg
        echom 'claudecode.vim: ' . v:exception
        echohl None
        return ''
    endtry
endfunction

function! claudecode#mcp_cleanup() abort
    try
        return luaeval('require("claudecode.mcp_server").cleanup()')
    catch
        echohl ErrorMsg
        echom 'claudecode.vim: ' . v:exception
        echohl None
        return 0
    endtry
endfunction

function! claudecode#open_log() abort
    try
        return luaeval('require("claudecode.logger").open_log_file()')
    catch
        echohl ErrorMsg
        echom 'claudecode.vim: ' . v:exception
        echohl None
        return 0
    endtry
endfunction

function! claudecode#send_selection() range abort
    " TODO: Implement selection sending functionality
endfunction

function! claudecode#send_buffer() abort
    " TODO: Implement buffer sending functionality
endfunction

function! claudecode#get_plugin_directory() abort
    " Get plugin root directory absolute path
    return s:plugin_path
endfunction

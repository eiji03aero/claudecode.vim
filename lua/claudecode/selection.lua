local selection = {}
local vim_compat = require('claudecode.vim_compat')
local logger = require('claudecode.logger')

function selection.get_relative_path(bufnr)
    bufnr = bufnr or 0
    local buffer_name = vim_compat.buf_get_name(bufnr)
    
    if buffer_name == "" then
        return nil, "Buffer has no name"
    end
    
    local relative_path = vim_compat.fnamemodify(buffer_name, ':.' )
    
    -- If the path doesn't start with './' and it's not an absolute path outside cwd
    if relative_path:match('^%.%.') then
        -- Path is outside current directory, use absolute path
        relative_path = buffer_name
    end
    
    return relative_path, nil
end

function selection.get_visual_selection()
    local start_pos = vim_compat.getpos("'<")
    local end_pos = vim_compat.getpos("'>")
    
    if not start_pos or not end_pos then
        return nil, nil, "No visual selection found"
    end
    
    local start_line = start_pos[2]
    local end_line = end_pos[2]
    local start_col = start_pos[3]
    local end_col = end_pos[3]
    
    logger.debug(string.format("Selection: lines %d-%d, cols %d-%d", start_line, end_line, start_col, end_col))
    
    -- Get selected lines
    local lines = vim_compat.getline(start_line, end_line)
    if type(lines) == "string" then
        lines = {lines}
    end
    
    -- Handle character-wise selection
    if start_line == end_line then
        -- Single line selection
        local line = lines[1] or ""
        lines[1] = line:sub(start_col, end_col)
    else
        -- Multi-line selection
        if lines[1] then
            lines[1] = lines[1]:sub(start_col)
        end
        if lines[#lines] and end_col > 1 then
            lines[#lines] = lines[#lines]:sub(1, end_col)
        end
    end
    
    local selected_text = table.concat(lines, "\n")
    local line_info = start_line == end_line and 
        string.format("line %d", start_line) or 
        string.format("lines %d-%d", start_line, end_line)
    
    return selected_text, line_info, nil
end

function selection.format_buffer_reference(relative_path)
    return string.format("@%s ", relative_path)
end

function selection.format_selection_reference(relative_path, line_info, selected_text)
    local reference = string.format("@%s %s ", relative_path, line_info)
    if selected_text and selected_text ~= "" then
        -- Add the selected text after a newline
        reference = reference .. "\n" .. selected_text .. "\n"
    end
    return reference
end

return selection

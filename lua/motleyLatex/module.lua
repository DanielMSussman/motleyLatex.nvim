local M = {}

--setup function just overwrites this with the main config table
M.config = {}

-- Get the background color from the 'Normal' highlight group
M.get_background_color = function()
    local bg_color = "FFFFFF" -- Default to white
    local hl_info = vim.fn.execute("highlight Normal")
    for line in hl_info:gmatch("[^\r\n]+") do
        local color_match = line:match("guibg=#(%x%x%x%x%x%x)")
        if color_match then
            bg_color = color_match
            break
        end
    end
    return bg_color
end

-- tcolorbox colback needs rgb (?), so here's a helper function
M.hex_to_rgb = function(hex)
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return r, g, b
end


-- Get all highlight groups and their associated colors
M.get_highlight_group_colors = function()
    local hl_group_color_map = {}
    local hl_info = vim.fn.execute("highlight")
    for line in hl_info:gmatch("[^\r\n]+") do



        local hl_group = line:match("%S+")
        local color_match = line:match("guifg=#(%x%x%x%x%x%x)")
        if color_match then
            hl_group_color_map[hl_group] = color_match
        end
    end
    return hl_group_color_map
end

-- A bunch of TeX characters need to be escaped
M.escape_latex_chars = function(str)
    return string.gsub(str, "[\\#$%&_^{}]", function(c) return "\\" .. c end)
end

-- generate the \textcolor[HTML]{hexCode} stuff to get a connected block of tokens with the given color
M.generate_token_latex = function(token, hl_group, hl_group_color_map)
    if not hl_group then
        return "\\texttt{" .. M.escape_latex_chars(token) .. "}"
    end

    local renamedHlGroup = hl_group
    local color_hex = hl_group_color_map[renamedHlGroup]

    if not color_hex then
        return "\\texttt{" .. M.escape_latex_chars(token) .. "}"
    end

    local color_command = string.format("\\textcolor[HTML]{%s}", color_hex)
    local escaped_token = M.escape_latex_chars(token)
    return string.format("%s{\\texttt{%s}}", color_command, escaped_token)
end

--use inspect_pos ("Inspect") to figure out what highlight group link we should use; process a given line.
M.generate_line_latex = function(line, line_num, buf_num, hl_group_color_map)
    local latex_output = ""
    local col = 0
    local line_length = #line
    while col < line_length do
        local inspect_result = vim.inspect_pos(buf_num, line_num - 1, col, {})
        --skip over whitespace, or things with no highlighting, and assign it to a raw \texttt{} string
        if not inspect_result or not inspect_result.treesitter or #inspect_result.treesitter == 0 then
            -- No highlights or error, find the next highlighted position or end of line
            local next_col = col + 1
            while next_col < line_length do
                local next_inspect_result = vim.inspect_pos(buf_num, line_num - 1, next_col, {})
                if next_inspect_result and next_inspect_result.treesitter and #next_inspect_result.treesitter > 0 then
                    break
                end
                next_col = next_col + 1
            end
            latex_output = latex_output .. M.generate_token_latex(line:sub(col + 1, next_col), nil, hl_group_color_map)
            col = next_col
        else
            -- Get the first highlight group, and find all connected tokens of the same highlight group
            local hl_group = inspect_result.treesitter[1].hl_group_link
            local end_col = col + 1
            while end_col < line_length do
                local next_inspect_result = vim.inspect_pos(buf_num, line_num - 1, end_col, {})
                if not next_inspect_result or not next_inspect_result.treesitter or #next_inspect_result.treesitter == 0 or next_inspect_result.treesitter[1].hl_group_link ~= hl_group then
                    break
                end
                end_col = end_col + 1
            end

            -- Generate LaTeX for the token
            local token = line:sub(col + 1, end_col)
            latex_output = latex_output .. M.generate_token_latex(token, hl_group, hl_group_color_map)

            col = end_col
        end
    end

    return latex_output .. "\\newline\n"
end

--given a start and end line, generate a tcolorbox with the specified options and all color highlighting.
M.generateLatexCodeblock = function(start_line,end_line)
    local buf_num = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf_num, start_line - 1, end_line, false)

    local hl_group_color_map = M.get_highlight_group_colors()
    local bg_color = M.get_background_color()
    local r, g, b = M.hex_to_rgb(bg_color)

    local tcolorbox_opts_str = "colback={rgb,255:red," .. r * 255 .. ";green," .. g * 255 .. ";blue," .. b * 255 .. "},"
    for k, v in pairs(M.config.tcolorbox_opts) do
        if type(v) == "boolean" then
            if v then -- Only add the option if it's true
                tcolorbox_opts_str = tcolorbox_opts_str .. k .. ","
            end
        elseif type(v) == "string" then
            tcolorbox_opts_str = tcolorbox_opts_str .. string.format("%s=%s,", k, v)
        end
    end

    -- Remove the trailing comma if present
    tcolorbox_opts_str = tcolorbox_opts_str:gsub(",$", "")

    -- Generate the LaTeX code with tcolorbox
    local latex_output = string.format([[
\begin{tcolorbox}[%s]
]], tcolorbox_opts_str)


    for line_num = start_line, end_line do
        latex_output = latex_output .. M.generate_line_latex(lines[line_num - start_line + 1], line_num, buf_num, hl_group_color_map)
    end

    latex_output = latex_output .. "\\end{tcolorbox}\n"
    return latex_output
end

--for testing as  I go
M.testFunction = function(greeting)
    -- local curline  = vim.api.nvim_win_get_cursor(0)[1]
    -- texOutput = M.generateLatexCodeblock(curline,curline+2)
    -- print(vim.inspect(texOutput))
end

return M

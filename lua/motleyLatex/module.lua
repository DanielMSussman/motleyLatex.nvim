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


-- Get all highlight groups and their associated colors...attributes are going to be things like italic, bold, underlined, etc
M.get_highlight_group_colors = function()
    local hl_group_attr_map = {}
    local hl_group_color_map = {}
    local hl_info = vim.fn.execute("highlight")
    for line in hl_info:gmatch("[^\r\n]+") do
        local hl_group = line:match("%S+")
        local fg_match = line:match("guifg=#(%x%x%x%x%x%x)")
        local bg_match = line:match("guibg=#(%x%x%x%x%x%x)")
        local attr_match = line:match("gui=([a-z,]+)")

        hl_group_attr_map[hl_group] = {}

        if fg_match then
            hl_group_attr_map[hl_group].fg = fg_match
        end

        if bg_match then
            hl_group_attr_map[hl_group].bg = bg_match
        end

        if attr_match then
            hl_group_attr_map[hl_group].attr = {}
            for attr in attr_match:gmatch("([^,]+)") do
                table.insert(hl_group_attr_map[hl_group].attr, attr)
            end
        end
    end
    return hl_group_attr_map
end

-- A bunch of TeX characters need to be escaped
M.escape_latex_chars = function(str)
    local replacements = {
        ["\\"] = "\\textbackslash",
        ["^"] = "\\textasciicircum",
        ["~"] = "\\textasciitilde",
    }
    str = string.gsub(str, "[\\^~]", function(c) return replacements[c] or c end)
    str = string.gsub(str, "[#$%&_{}]", function(c) return "\\" .. c end)
    return str
end

-- generate the \textcolor[HTML]{hexCode} stuff to get a connected block of tokens with the given color
M.generateTokenLatex = function(token, hl_group, hl_group_attr_map)
    local escaped_token = M.escape_latex_chars(token)
    local attributes = hl_group_attr_map[hl_group]

    if not hl_group then
        return "\\ttfamily{" .. escaped_token .. "}"
    end

    local tex_output = "\\ttfamily{"..escaped_token .."}"

    if attributes.attr then
        for _, attr in ipairs(attributes.attr) do
            if attr == "bold" then
                tex_output = "\\textbf{" .. tex_output .. "}"
            elseif attr == "italic" then
                tex_output = "\\textit{" .. tex_output .. "}"
            elseif attr == "underline" then
                tex_output = "\\underbar{" .. tex_output .. "}"
            end
        end
    end

    if attributes.fg then
        tex_output = string.format("\\textcolor[HTML]{%s}{%s}", attributes.fg, tex_output)
    end

    return tex_output
    -- return tex_output .. escaped_token .. "}"
end

--use inspect_pos ("Inspect") to figure out what highlight group link we should use; process a given line.
M.generateLineLatex = function(line, line_num, buf_num, hl_group_attr_map)
    local latex_output = ""
    local col = 0
    local line_length = #line

    -- Handle leading whitespace
    local whitespace = line:sub(col + 1, line_length):match("^%s*")
    latex_output = latex_output .. "\\hspace*{" .. tostring(#whitespace) .. "ex}"
    col = col + #whitespace

    while col < line_length do
        local inspect_result = vim.inspect_pos(buf_num, line_num - 1, col, {})

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
             local token = line:sub(col + 1, next_col)
            latex_output = latex_output .. M.generateTokenLatex(token, nil, hl_group_attr_map)

            col = next_col
        else
             local irLen = #inspect_result.treesitter
             local hl_group = inspect_result.treesitter[irLen].hl_group_link
             if hl_group == "@spell" then
                 hl_group = inspect_result.treesitter[1].hl_group_link
             end

            -- Find the end of the continuous run of the SAME highlight group AND attributes
            local end_col = col + 1
            local current_attributes = hl_group_attr_map[hl_group]

            while end_col < line_length do
                local next_inspect_result = vim.inspect_pos(buf_num, line_num - 1, end_col, {})
                 if not next_inspect_result or not next_inspect_result.treesitter or #next_inspect_result.treesitter == 0 then
                    break -- No more highlighting
                end
                local next_hl_group = next_inspect_result.treesitter[#next_inspect_result.treesitter].hl_group_link
                if next_hl_group == "@spell" then  --handle spellcheck weirdness
                   next_hl_group = next_inspect_result.treesitter[1].hl_group_link
                end
                local next_attributes = hl_group_attr_map[next_hl_group]

                -- Check if BOTH highlight group AND attributes are the same
                if next_hl_group ~= hl_group or not next_attributes or not M.compareAttributes(current_attributes, next_attributes) then
                    break
                end

                end_col = end_col + 1
            end

            -- Generate LaTeX for the ENTIRE token
            local token = line:sub(col + 1, end_col)
            latex_output = latex_output .. M.generateTokenLatex(token, hl_group, hl_group_attr_map)
            col = end_col
        end
    end

    return latex_output .. "\\newline\n"
end

M.compareAttributes = function(attr1, attr2)
    if attr1 == nil and attr2 == nil then return true end --both nil
    if attr1 == nil or attr2 == nil then return false end --one is nil, the other isn't
    if attr1.fg ~= attr2.fg or attr1.bg ~= attr2.bg then
        return false
    end

    -- Compare 'attr' tables (bold, italic, underline)
    if attr1.attr == nil and attr2.attr == nil then return true end
    if attr1.attr == nil or attr2.attr == nil then return false end
    if #attr1.attr ~= #attr2.attr then
        return false
    end
    table.sort(attr1.attr)  -- Sort to ensure order doesn't matter
    table.sort(attr2.attr)
    for i = 1, #attr1.attr do
        if attr1.attr[i] ~= attr2.attr[i] then
            return false
        end
    end

    return true
end

--given a start and end line, generate a tcolorbox with the specified options and all color highlighting.
M.generateLatexCodeblock = function(start_line,end_line)
    local buf_num = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf_num, start_line - 1, end_line, false)

    local hl_group_color_map = M.get_highlight_group_colors()
    local bg_color = M.get_background_color()
    local r, g, b = M.hex_to_rgb(bg_color)

    local tcolorbox_opts_str = "\ncolback={rgb,255:red," .. r * 255 .. ";green," .. g * 255 .. ";blue," .. b * 255 .. "},\n"
    for k, v in pairs(M.config.tcolorbox_opts) do
        if type(v) == "boolean" then
            if v then -- Only add the option if it's true
                tcolorbox_opts_str = tcolorbox_opts_str .. k .. ","
            end
        elseif type(v) == "string" then
            tcolorbox_opts_str = tcolorbox_opts_str .. string.format("%s=%s,\n", k, v)
        end
    end

    -- Remove the trailing comma if present
    tcolorbox_opts_str = tcolorbox_opts_str:gsub(",$", "")

    -- Generate the LaTeX code with tcolorbox
    local latex_output = string.format([[
\begin{tcolorbox}[%s]
]], tcolorbox_opts_str)


    for line_num = start_line, end_line do
        if line_num == end_line then
            latex_output = latex_output .. M.generateLineLatex(lines[line_num - start_line + 1], line_num, buf_num, hl_group_color_map):gsub("\\newline\n$","")
        else
            latex_output = latex_output .. M.generateLineLatex(lines[line_num - start_line + 1], line_num, buf_num, hl_group_color_map)
        end
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

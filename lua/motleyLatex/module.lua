local M = {}

--setup function just overwrites this with the main config table
M.config = {}

-- Get the background color from the 'Normal' highlight group
M.get_background_color = function()
    local hl_info = vim.api.nvim_get_hl_by_name("Normal", true)

    if hl_info and hl_info.background then
        return string.format("%06x", hl_info.background)
    end

    return "FFFFFF"
end

-- tcolorbox colback needs rgb (?), so here's a helper function
M.hex_to_rgb = function(hex)
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return r, g, b
end
M.integer_to_rgb = function(c)
  local r = bit.band(bit.rshift(c, 16), 0xFF) / 255
  local g = bit.band(bit.rshift(c, 8), 0xFF) / 255
  local b = bit.band(c, 0xFF) / 255
  return r, g, b
end


-- Get all highlight groups and their associated colors...attributes are going to be things like italic, bold, underlined, etc
M.get_highlight_group_colors = function()
    return vim.api.nvim_get_hl(0, {})
end

-- A bunch of TeX characters need to be escaped
M.escape_latex_chars = function(str)
    local replacements = {
        ['\\'] = '\\textbackslash{}',
        ['%'] = '\\%',
        ['$'] = '\\$',
        ['#'] = '\\#',
        ['&'] = '\\&',
        ['_'] = '\\_',
        ['{'] = '\\{',
        ['}'] = '\\}',
        ['^'] = '\\textasciicircum{}',
        ['~'] = '\\textasciitilde{}'
    }

    return string.gsub(str, "[\\%%$#&_{}%^~]",
        function(c)
            return replacements[c]
        end
    )
end


-- generate the \textcolor[HTML]{hexCode} stuff to get a connected block of tokens with the given color
M.generateTokenLatex = function(token, hl_group, hl_group_map)
    local escaped_token = M.escape_latex_chars(token)
    local attributes = hl_group and hl_group_map[hl_group]

    if not attributes then
        return "\\ttfamily{" .. escaped_token .. "}"
    end

    local tex_output = "\\ttfamily{" .. escaped_token .. "}"

    if attributes.bold then
        tex_output = "\\textbf{" .. tex_output .. "}"
    end
    if attributes.italic then
        tex_output = "\\textit{" .. tex_output .. "}"
    end
    if attributes.underline then
        tex_output = "\\underbar{" .. tex_output .. "}"
    end
    -- You can easily add more attributes here, like 'undercurl', 'strikethrough', etc.

    if attributes.fg then
        local hex_color = string.format("%06x", attributes.fg)
        tex_output = string.format("\\textcolor[HTML]{%s}{%s}", hex_color, tex_output)
    end

    return tex_output
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
    -- If both are nil (e.g., for unhighlighted text), they are the same.
    if not attr1 and not attr2 then return true end
    -- If one is nil and the other is not, they are different.
    if not attr1 or not attr2 then return false end

    -- Compare colors (integers or nil).
    if attr1.fg ~= attr2.fg then return false end
    if attr1.bg ~= attr2.bg then return false end

    -- Compare boolean attributes 
    if (attr1.bold or false) ~= (attr2.bold or false) then return false end
    if (attr1.italic or false) ~= (attr2.italic or false) then return false end
    if (attr1.underline or false) ~= (attr2.underline or false) then return false end

    return true
end

--given a start and end line, generate a tcolorbox with the specified options and all color highlighting.
M.generateLatexCodeblock = function(startLine,endLine)
    local buf_num = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf_num, startLine - 1, endLine, false)

    local hl_map = M.get_highlight_group_colors()

    local normal_group = hl_map.Normal or {}
    local bg_color_int = normal_group.bg or 0xFFFFFF -- Default to white

    local r, g, b = M.integer_to_rgb(bg_color_int)

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


    for line_num = startLine, endLine do
        if line_num == endLine then
            latex_output = latex_output .. M.generateLineLatex(lines[line_num - startLine + 1], line_num, buf_num, hl_map):gsub("\\newline\n$","")
        else
            latex_output = latex_output .. M.generateLineLatex(lines[line_num - startLine + 1], line_num, buf_num, hl_map)
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

M.generateAllMotley = function(opts)
    local args = vim.split(opts.args, "%s+")
    local commentString = nil
    local colorSchemes = nil
     if #args == 1 and args[1] == "" then
        commentString = "##"
        colorSchemes = { "kanagawa-lotus" }
    elseif #args < 2 then
        print("Error: Not enough arguments.")
        print('Usage: :GenerateAllMotley "<commentString>" <scheme1> <scheme2> ...')
        return
    else
        commentString = table.remove(args, 1)
        colorSchemes = args
    end

    local originalScheme = vim.g.colors_name
    -- vim.notify("Original colorscheme: " .. originalScheme)

    local marker_pattern = "^" .. vim.pesc(commentString) .. "%s+(.*)%.tex%s*$"

    local blocks = {}
    local bufferLines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local currentBlock = nil

    for i, line in ipairs(bufferLines) do
        local filename = line:match(marker_pattern)
        if filename then
            if currentBlock then
                local endLine = i - 1
                while endLine >= currentBlock.startLine and vim.trim(bufferLines[endLine]) == "" do
                    endLine = endLine - 1
                end
                currentBlock.endLine = endLine
            end
            currentBlock = {
                filename = filename,
                startLine = i + 1,
            }
            table.insert(blocks, currentBlock)
        end
    end

    if currentBlock then
        local endLine = #bufferLines
        while endLine >= currentBlock.startLine and vim.trim(bufferLines[endLine]) == "" do
            endLine = endLine -1
        end
        currentBlock.endLine = endLine
    end


    if #blocks == 0 then
        vim.notify("No blocks matching '" .. commentString .. " filename.tex' format found.")
        return
    end

    for _, scheme in ipairs(colorSchemes) do
        -- vim.notify("Applying colorscheme: " .. scheme)
        vim.cmd("colorscheme " .. scheme)
        vim.cmd("redraw")
        vim.wait(50)

        for _, block in ipairs(blocks) do
            if block.startLine <= block.endLine then
                vim.notify("Generating " .. block.filename .. ".tex ...")
                local cmd = string.format(":%d,%d MotleyLatex %s", block.startLine, block.endLine, block.filename)
                print(cmd)
                vim.cmd(cmd)
            end
        end
    end

    -- vim.notify("Automation complete. Restoring original colorscheme.")
    vim.cmd("colorscheme " .. originalScheme)
    vim.cmd("redraw")
end

return M

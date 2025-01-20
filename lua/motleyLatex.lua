-- main module file
local module = require("motleyLatex.module")

local M = {}

M.config = {
    tcolorbox_opts = {
    colframe = "black!40",
    boxrule = "0.5pt",
    width = "0.9\\textwidth",
  },
}

-- merge the config, and define a user command
M.setup = function(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    module.config = M.config

    vim.api.nvim_create_user_command('MotleyLatex',
        function(opts)
            local module = require("motleyLatex.module")
            local start_line, end_line

            if opts.range == 0 then -- No range given, use entire buffer
                start_line = 1
                end_line = vim.api.nvim_buf_line_count(0)
            else -- Visual selection or range given
                local ok, res = pcall(function()
                    return vim.api.nvim_buf_get_mark(0, "<")
                end)
                if not ok then
                    print("Error: Invalid visual selection")
                    return
                end
                start_line = res[1]
                end_line = vim.api.nvim_buf_get_mark(0, ">")[1]
            end

            local latex_code = module.generateLatexCodeblock(start_line, end_line)

            -- Determine output file name
            local output_file
            if opts.args and opts.args ~= "" then
                -- Use the provided argument as the output file basename
                output_file = opts.args .. '.tex'
            else
                -- Use the current file's name as the default
                output_file = vim.fn.expand('%:p:r') .. '.tex'
            end

            -- Write the LaTeX code to the output file
            local file = io.open(output_file, "w")
            if file then
                file:write(latex_code)
                file:close()
                print("LaTeX code written to " .. output_file)
            else
                print("Error: Could not write to file " .. output_file)
            end
        end,
        { range = true, nargs = '?', complete = 'file', desc = 'save a tcolorbox corresponding to the current color scheme. Acts on whole buffer or visual selection. optional argument specifies the filename that will be saved' })

    -- vim.api.nvim_create_user_command("MotleyLatexTesting",
    --     function()
    --         require("motleyLatex").pluginTesting()
    --     end,{desc = 'test'}
    -- )

end

M.pluginTesting = function()
    module.testFunction(M.config.opt)
end

return M

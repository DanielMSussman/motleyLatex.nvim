-- main module file
local module = require("motleyLatex.module")

local M = {}

M.config = {
    tcolorbox_opts = {
    top= "0.5pt",
    bottom= "0.5pt",
    colframe = "black!40",
    boxrule = "0.5pt",
    width = "0.9\\textwidth",
  },
}

-- merge the config, and define a user command
M.setup = function(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    module.config = M.config --- do this here *and* later so that one can overwrite the title each time

    vim.api.nvim_create_user_command('MotleyLatex',
        function(opts)
            local module = require("motleyLatex.module")

            local startLine = opts.line1
            local endLine = opts.line2

            -- Argument parsing for filename and title
            local args = vim.fn.split(opts.args, [[\s+]])
            local filenameArg = args[1]
            local titleArg = args[2]

            -- Determine output file name, possibly using an environment var as root
            local outputFile
            if filenameArg and filenameArg ~= "" then
                local base_dir = vim.env.MOTLEY_ROOT or vim.fn.getcwd()
                outputFile = base_dir .. "/" .. filenameArg .. '.tex'
            else
                outputFile = vim.fn.expand('%:p:r') .. '.tex'
            end

            -- Pass title to the module config if it exists
            if titleArg then
                module.config.tcolorbox_opts.title = titleArg
            else
                -- Clear previous title if none is provided this time
                module.config.tcolorbox_opts.title = nil
            end

            -- Generate the LaTeX code
            local latex_code = module.generateLatexCodeblock(startLine, endLine)

            -- Ensure the parent directory exists
            local dir = vim.fn.fnamemodify(outputFile, ":h")
            if vim.fn.isdirectory(dir) == 0 then
                vim.fn.mkdir(dir, "p")
            end

            -- Write the LaTeX code to the output file
            local file = io.open(outputFile, "w")
            if file then
                file:write(latex_code)
                file:close()
                -- vim.notify("LaTeX code written to " .. outputFile)
            else
                vim.notify("Error: Could not write to file " .. outputFile, vim.log.levels.ERROR)
            end
        end,
    {
        range = true, -- Let Neovim handle parsing the range
        nargs = '*',
        complete = 'file',
        desc = 'Save a tcolorbox from the current buffer or selection.'
    })

    -- vim.api.nvim_create_user_command("MotleyLatexTesting",
    --     function()
    --         require("motleyLatex").pluginTesting()
    --     end,{desc = 'test'}
    -- )
    vim.api.nvim_create_user_command('GenerateAllMotley',
        function(opts)
            local module = require("motleyLatex.module")
            module.generateAllMotley(opts)
        end,
        { nargs = "*", complete = "color",
            desc = "Generate motleyLatex files for every block in the current file that starts with a given comment string.", }
    )

    vim.api.nvim_create_user_command('GenerateDelimitedMotleyBlocks',
        function(opts)
            local module = require("motleyLatex.module")
            module.generateDelimitedMotleyBlocks(opts)
        end,
        { nargs = "*", complete = "color",
            desc = "Generate motleyLatex files for every block in the current file enclosed by #@@ and #@@end.", }
    )
end

M.pluginTesting = function()
    module.testFunction(M.config.opt)
end

return M

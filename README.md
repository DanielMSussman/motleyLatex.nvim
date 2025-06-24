 # motleyLatex

A Neovim plugin that translates code in a buffer to a LaTeX `tcolorbox` environment, preserving preserving syntax highlighting from Neovim (using Tree-sitter) and your current color scheme


https://github.com/user-attachments/assets/b0da6e8b-ad13-449b-8c50-c020b3ed6452


## Motivation

As a Neovim user, you've (probably) meticulously crafted the look of your coding environment, complete with a color scheme that is aesthetically pleasing and enhances readability. When it comes to showing code in LaTeX documents, though, you're often forced to compromise.
Existing solutions like [minted](https://ctan.org/pkg/minted?lang=en) and [listings](https://ctan.org/pkg/listings) are like the TikZ of syntax highlighting: extremely powerful, but requiring much manual configuration to define the look of each code blcok.

An alternate approach with graphics is to create an image in any other way and then use, e.g., `includegraphics` to embed it into your document. 
The [chroma_code](https://github.com/TomLebeda/chroma_code/) CLI tool ran with this idea, generating a `listings` environment by defining a custom color scheme, writing new tree-sitter queries for a handful of languages, and consuming the output of tree-sitter applied with those queries to existing code.

`motleyLatex` takes this approach to it's logical conclusion (within the Neovim ecosystem). 
Why not just directly capture the color scheme and syntax highlighting provided by Neovim directly, allowing you to replicate the look of your code in a LaTeX document?
The plugin consumes the contents and visual style of the current code buffer (or a visual selection of it) and outputs the relevant information to a new `.tex` file that uses the power and flexibility of `tcolorbox` to create a beautifully styled code block that can be directly `input` into a LaTeX file and compiled.


## Installation with `lazy.nvim`

```lua
{
    `DanielMSussman/motleyLatex.nvim`,
    dependencies = {`nvim-treesitter/nvim-treesitter`,},
    config = function()
        -- use tcolorbox_opts to overwrite any of the default options, or add new ones
        require("motleyLatex").setup({
                    tcolorbox_opts = {
                        colframe = "black!40",
                        boxrule = "0.5pt", 
                        width = "0.9\\textwidth",
                    },
        })
    end
}
```

### Prerequisits

* Neovim 0.9+ (`vim.inspect_pos()` used under the hood)

* `nvim-treesitter` plugin for syntax highlighting

* Your favorite colorscheme

* LaTeX packages

    * xcolor

    * tcolorbox

## Usage

1. Open code in Neovim
2. Enable tree-sitter highlighting if it isn't already (`:TSBufEnable`)
3. Run the plugin command `:MotleyLatex [optionalOutputFilename] ["optional title"]`. This operates on the whole buffer or on the current visual selection. If no filename is provided, the name of the code file is used as the base filename. If the second optional argument (enclosed in quotes) is provided, it is used for the tcolorbox title.
4. Include the generated `filename.tex` file in your LaTeX document:

```
\documentclass[12pt]{article}
\usepackage{xcolor}
\usepackage{tcolorbox}
\begin{document}

Here's some code generated from Neovim using the \texttt{MotleyLatex} command:
\input{filename.tex}
\end{document}
```

## Configuration and operation

Under the hood, the command basically attempts to output a `tcolorbox` environment with both the background color and text syntax highlighting of your current color scheme preserved.
Calling the setup function as in the Installation example above allows you to override or set any of the `tcolorbox` options.

### Notes

The plugin uses `vim.inspect_pos()` to get highlight information directly from Neovim, (hopefully) ensuring accurate color and style rendering. Those colors and style attributes come from the `guifg`, `guibg`, and `gui` attributes of highlight groups.


### Thanks

If, for some unexpected reason, you found this helpful and would like to offer support:

[![Buy Me a Coffee](https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=&slug=danielmsussman&button_colour=FFDD00&font_colour=000000&font_family=Poppins&outline_colour=000000&coffee_colour=ffffff)](https://www.buymeacoffee.com/danielmsussman)

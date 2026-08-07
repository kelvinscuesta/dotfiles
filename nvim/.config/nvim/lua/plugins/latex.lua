-- VimTeX: LaTeX editing, compilation, PDF viewing
-- Keymaps (localleader = space): <space>ll compile, <space>lv view, <space>lc clean
return {
  'lervag/vimtex',
  lazy = false,
  init = function()
    vim.g.vimtex_view_method = 'skim'
    vim.g.vimtex_compiler_method = 'latexmk'
  end,
}

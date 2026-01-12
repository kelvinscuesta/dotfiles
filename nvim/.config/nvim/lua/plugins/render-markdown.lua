-- Render-markdown: prettify markdown in-buffer
-- Renders headings, code blocks, lists, checkboxes with icons and highlights
-- Makes markdown files more readable without leaving neovim
return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    completions = { lsp = { enabled = true } }, -- enable LSP completions
  },
}

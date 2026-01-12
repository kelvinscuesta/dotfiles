-- Lazydev: Lua LSP enhancement for neovim config development
-- Provides completions, type hints, and docs for vim.*, vim.api.*, plugin APIs
-- Only loads for lua files (ft = 'lua')
return {
  'folke/lazydev.nvim',
  ft = 'lua', -- only load for lua files
  opts = {
    library = {
      { path = '${3rd}/luv/library', words = { 'vim%.uv' } }, -- libuv bindings (async I/O)
      { path = 'snacks.nvim', words = { 'Snacks' } }, -- snacks.nvim types
    },
  },
}

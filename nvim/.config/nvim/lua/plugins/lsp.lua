-- LSP plugins: Mason for installation, blink for completion
-- Server configs in lsp/*.lua, behavior in config/lsp.lua
return {
  { 'williamboman/mason.nvim', opts = {} },
  {
    'williamboman/mason-lspconfig.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    opts = {
      automatic_enable = {
        exclude = { 'ruby_lsp', 'sorbet', 'rubocop' },
      },
      automatic_installation = {
        exclude = { 'ruby_lsp', 'sorbet', 'rubocop' },
      },
    },
  },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    opts = {
      ensure_installed = {
        'gopls', 'bashls', 'graphql', 'vtsls', 'eslint',
        'basedpyright', 'ruff', 'lua_ls', 'texlab',
        'stylua',
      },
    },
  },
}

-- Conform: code formatter that runs external tools (prettier, stylua, etc.)
-- Formats on save and provides <leader>f for manual formatting
-- Falls back to LSP formatting if no formatter configured
return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' }, -- load before saving (for format on save)
  cmd = { 'ConformInfo' }, -- :ConformInfo shows active formatters
  keys = {
    {
      '<leader>f',
      function()
        require('conform').format { async = true, lsp_format = 'fallback' }
      end,
      mode = '', -- all modes
      desc = 'Format buffer',
    },
  },
  opts = {
    notify_on_error = false, -- don't show error notifications

    -- Format on Save: runs before writing buffer
    format_on_save = function(bufnr)
      -- disable for languages without standardized style
      local disable_filetypes = { c = true, cpp = true }
      local lsp_format_opt
      if disable_filetypes[vim.bo[bufnr].filetype] then
        lsp_format_opt = 'never'
      else
        lsp_format_opt = 'fallback' -- use LSP if no formatter
      end
      return {
        timeout_ms = 500,
        lsp_format = lsp_format_opt,
      }
    end,

    -- Formatters by Filetype
    -- stop_after_first: try prettierd, fall back to prettier if unavailable
    formatters_by_ft = {
      lua = { 'stylua' },
      python = { 'ruff_organize_imports', 'ruff_format' }, -- sort imports, then format
      javascript = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
      typescript = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
      javascriptreact = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
      typescriptreact = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
      css = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
      html = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
      json = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
      graphql = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
      ruby = { 'rubocop' },
    },
  },
}

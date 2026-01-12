return {
  'rachartier/tiny-inline-diagnostic.nvim',
  event = 'VeryLazy', -- Or `LspAttach`
  priority = 1000, -- needs to be loaded in first
  config = function()
    require('tiny-inline-diagnostic').setup {
      preset = 'classic',
      options = {
        break_line = {
          -- Enable the feature to break messages after a specific length
          enabled = true,

          -- Number of characters after which to break the line
          after = 30,
        },
        throttle = 0,
        show_source = {
          enabled = true,
          if_many = false,
        },
        multilines = {
          -- Enable multiline diagnostic messages
          enabled = true,

          -- Always show messages on all lines for multiline diagnostics
          always_show = true,
        },
      },
    }
    vim.diagnostic.config { virtual_text = false } -- Only if needed in your configuration, if you already have native LSP diagnostics
  end,
}

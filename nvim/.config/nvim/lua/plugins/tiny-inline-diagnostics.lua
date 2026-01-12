-- Tiny-inline-diagnostic: pretty inline diagnostic messages
-- Replaces default virtual_text with formatted, wrapped diagnostic display
-- Shows error/warning messages inline with better readability
return {
  'rachartier/tiny-inline-diagnostic.nvim',
  event = 'VeryLazy',
  priority = 1000, -- load early
  config = function()
    require('tiny-inline-diagnostic').setup {
      preset = 'classic',
      options = {
        break_line = { enabled = true, after = 30 }, -- wrap long messages
        throttle = 0, -- no delay
        show_source = { enabled = true, if_many = false }, -- show diagnostic source
        multilines = { enabled = true, always_show = true }, -- show on all affected lines
      },
    }
    vim.diagnostic.config { virtual_text = false } -- disable default virtual_text
  end,
}

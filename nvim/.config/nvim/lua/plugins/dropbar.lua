-- Dropbar: breadcrumb navigation in the winbar (top of window)
-- Shows: file > class > function > scope - click or use keymaps to navigate
-- Keymaps: <leader>; pick symbol, [; go to context start, ]; next context
return {
  {
    'Bekaboo/dropbar.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      local dropbar_api = require 'dropbar.api'
      vim.keymap.set('n', '<Leader>;', dropbar_api.pick, { desc = 'Pick symbols in winbar' })
      vim.keymap.set('n', '[;', dropbar_api.goto_context_start, { desc = 'Go to start of current context' })
      vim.keymap.set('n', '];', dropbar_api.select_next_context, { desc = 'Select next context' })
    end,
  },
}

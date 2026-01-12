-- Mini.nvim: collection of small, focused lua plugins
-- Using: ai (textobjects), surround, map, statusline
return {
  'echasnovski/mini.nvim',
  config = function()
    -- mini.ai: extended textobjects for around/inside motions
    -- va) = select around parens, ci' = change inside quotes, yinq = yank inside next quote
    require('mini.ai').setup { n_lines = 500 }

    -- mini.surround: add/delete/replace surrounding chars
    -- saiw) = surround word with (), sd' = delete quotes, sr)' = replace () with ''
    require('mini.surround').setup()

    -- mini.map: code minimap (like VSCode's scrollbar preview)
    require('mini.map').setup()

    -- mini.statusline: simple, fast statusline
    local statusline = require 'mini.statusline'
    statusline.setup { use_icons = vim.g.have_nerd_font }
    ---@diagnostic disable-next-line: duplicate-set-field
    statusline.section_location = function()
      return '%2l:%-2v' -- LINE:COL format
    end
  end,
}

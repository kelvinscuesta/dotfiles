-- Which-key: popup showing available keybindings after pressing a key
-- Press <leader> and wait to see all leader keymaps
-- Groups keymaps by prefix for discoverability
return {
  'folke/which-key.nvim',
  event = 'VimEnter',
  opts = {
    delay = 0, -- show popup immediately (ms)
    icons = {
      mappings = vim.g.have_nerd_font, -- use nerd font icons
      keys = vim.g.have_nerd_font and {} or { -- fallback text for non-nerd fonts
        Up = '<Up> ', Down = '<Down> ', Left = '<Left> ', Right = '<Right> ',
        C = '<C-…> ', M = '<M-…> ', D = '<D-…> ', S = '<S-…> ',
        CR = '<CR> ', Esc = '<Esc> ', BS = '<BS> ', Space = '<Space> ', Tab = '<Tab> ',
        NL = '<NL> ', ScrollWheelDown = '<ScrollWheelDown> ', ScrollWheelUp = '<ScrollWheelUp> ',
        F1 = '<F1>', F2 = '<F2>', F3 = '<F3>', F4 = '<F4>', F5 = '<F5>', F6 = '<F6>',
        F7 = '<F7>', F8 = '<F8>', F9 = '<F9>', F10 = '<F10>', F11 = '<F11>', F12 = '<F12>',
      },
    },
    -- Key group labels (shown in which-key popup)
    spec = {
      { '<leader>c', group = 'Code', mode = { 'n', 'x' } },
      { '<leader>d', group = 'Document' },
      { '<leader>r', group = 'Rename' },
      { '<leader>s', group = 'Search' },
      { '<leader>t', group = 'Toggle' },
      { '<leader>h', group = 'Git Hunk', mode = { 'n', 'v' } },
    },
  },
}

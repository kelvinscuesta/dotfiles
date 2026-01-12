vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.keymap.set('n', 'Q', '<nop>')

-- Move cursor to middle for seamless navigation in a buffer
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Personal keymaps I like
vim.keymap.set('n', '<leader>w', '<cmd>w!<CR>', { desc = 'Save the current buffer in normal mode' })
vim.keymap.set('n', '<leader>q', '<cmd>q<CR>', { desc = 'Close the current buffer' })
vim.keymap.set('i', 'jk', '<Esc>', { desc = 'Esc with jk in insert mode', noremap = true })

-- Buffer keymaps
-- Navigate to the next buffer
vim.keymap.set('n', '<leader>bn', ':bnext<CR>', { noremap = true, silent = true })

-- Navigate to the previous buffer
vim.keymap.set('n', '<leader>bp', ':bprevious<CR>', { noremap = true, silent = true })

-- Close the current buffer
vim.keymap.set('n', '<leader>bd', ':bdelete<CR>', { noremap = true, silent = true })

-- Switch to the last used buffer
vim.keymap.set('n', '<leader>bl', ':b#<CR>', { noremap = true, silent = true })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

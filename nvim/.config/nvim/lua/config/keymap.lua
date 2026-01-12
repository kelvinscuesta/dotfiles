-- Leader Keys
vim.g.mapleader = ' ' -- space as leader key (used for custom shortcuts)
vim.g.maplocalleader = ' ' -- space as local leader (for filetype-specific maps)

-- Disabled Keys
vim.keymap.set('n', 'Q', '<nop>') -- disable Ex mode (easy to hit accidentally)

-- Scrolling: keep cursor centered when jumping
vim.keymap.set('n', '<C-d>', '<C-d>zz') -- half-page down + center
vim.keymap.set('n', '<C-u>', '<C-u>zz') -- half-page up + center

-- Window Navigation: Ctrl+hjkl to move between splits
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Focus left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Focus right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Focus lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Focus upper window' })

-- Terminal: Esc exits terminal mode (default is <C-\><C-n>)
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Search: clear highlights with Esc
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Quick Actions
vim.keymap.set('n', '<leader>w', '<cmd>w!<CR>', { desc = 'Save buffer' })
vim.keymap.set('n', '<leader>q', '<cmd>q<CR>', { desc = 'Close window' })
vim.keymap.set('i', 'jk', '<Esc>', { desc = 'Exit insert mode', noremap = true })

-- Buffer Navigation
vim.keymap.set('n', '<leader>bn', ':bnext<CR>', { desc = 'Next buffer', noremap = true, silent = true })
vim.keymap.set('n', '<leader>bp', ':bprevious<CR>', { desc = 'Previous buffer', noremap = true, silent = true })
vim.keymap.set('n', '<leader>bd', ':bdelete<CR>', { desc = 'Delete buffer', noremap = true, silent = true })
vim.keymap.set('n', '<leader>bl', ':b#<CR>', { desc = 'Last buffer', noremap = true, silent = true })

-- Autocommands
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Briefly highlight yanked text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

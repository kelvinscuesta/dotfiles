-- Leader Keys
vim.g.mapleader = ' ' -- space as leader key (used for custom shortcuts)
vim.g.maplocalleader = ' ' -- space as local leader (for filetype-specific maps)

-- Disabled Keys
vim.keymap.set('n', 'Q', '<nop>') -- disable Ex mode (easy to hit accidentally)

-- Scrolling: keep cursor centered when jumping
vim.keymap.set('n', '<C-d>', '<C-d>zz') -- half-page down + center
vim.keymap.set('n', '<C-u>', '<C-u>zz') -- half-page up + center

-- Window Navigation: C-h/j/k/l handled by vim-tmux-navigator plugin
-- (seamless navigation between nvim splits and tmux panes)

-- Terminal: Esc exits terminal mode (default is <C-\><C-n>)
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Search: clear highlights with Esc
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Quick Actions
vim.keymap.set('n', '<leader>w', '<cmd>w!<CR>', { desc = 'Save buffer' })
vim.keymap.set('n', '<leader>q', '<cmd>q<CR>', { desc = 'Close window' })
vim.keymap.set('i', 'jk', '<Esc>', { desc = 'Exit insert mode' })

-- Buffer Navigation (bd handled by snacks.bufdelete)
vim.keymap.set('n', '<leader>bn', '<cmd>bnext<CR>', { desc = 'Next buffer', silent = true })
vim.keymap.set('n', '<leader>bp', '<cmd>bprevious<CR>', { desc = 'Previous buffer', silent = true })
vim.keymap.set('n', '<leader>bl', '<cmd>b#<CR>', { desc = 'Last buffer', silent = true })

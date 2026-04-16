-- Seamless navigation between tmux panes and nvim splits with C-h/j/k/l
return {
  'christoomey/vim-tmux-navigator',
  event = 'VeryLazy',
  keys = {
    { '<C-h>', '<cmd>TmuxNavigateLeft<cr>', desc = 'Navigate left (tmux-aware)' },
    { '<C-j>', '<cmd>TmuxNavigateDown<cr>', desc = 'Navigate down (tmux-aware)' },
    { '<C-k>', '<cmd>TmuxNavigateUp<cr>', desc = 'Navigate up (tmux-aware)' },
    { '<C-l>', '<cmd>TmuxNavigateRight<cr>', desc = 'Navigate right (tmux-aware)' },
  },
}

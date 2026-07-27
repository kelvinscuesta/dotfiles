-- Utility plugins
return {
  -- vim-sleuth: auto-detect indent settings (tabs vs spaces, width)
  'tpope/vim-sleuth',

  -- todo-comments: highlight and search TODO, FIXME, HACK, etc.
  { 'folke/todo-comments.nvim', event = 'VimEnter', opts = { signs = true } },
}

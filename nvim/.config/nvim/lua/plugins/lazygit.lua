-- Lazygit: terminal UI for git (opens in floating window)
-- Full-featured git client: stage, commit, push, rebase, stash, etc.
-- Keymap: <leader>lg opens lazygit
return {
  'kdheepak/lazygit.nvim',
  lazy = true, -- only load when needed
  cmd = {
    'LazyGit', -- open lazygit for repo
    'LazyGitConfig', -- open lazygit config
    'LazyGitCurrentFile', -- open with current file's history
    'LazyGitFilter', -- open with commit filter
    'LazyGitFilterCurrentFile', -- filter commits for current file
  },
  keys = {
    { '<leader>lg', '<cmd>LazyGit<cr>', desc = 'LazyGit' },
  },
}

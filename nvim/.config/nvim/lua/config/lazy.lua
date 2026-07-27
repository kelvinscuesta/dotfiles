-- Bootstrap: auto-install lazy.nvim if not present
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim' -- ~/.local/share/nvim/lazy/lazy.nvim
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  -- clone with blob:none for faster download (no file history)
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath) -- add lazy.nvim to runtime path

-- Plugin Manager Setup
require('lazy').setup {
  -- Plugin Sources
  spec = {
    { import = 'plugins' }, -- load all files from lua/plugins/
  },

  -- Default Behavior
  defaults = {
    lazy = false, -- load plugins at startup (set true for lazy-load by default)
    version = false, -- use latest commit, not releases (many plugins have outdated tags)
  },

  -- Update Checker: runs in background, no notifications
  checker = { enabled = true, notify = false },

  -- Performance: disable unused built-in plugins
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip', -- editing gzipped files
        'netrwPlugin', -- built-in file explorer (using other plugins)
        'tarPlugin', -- editing tar archives
        'tohtml', -- :TOhtml command
        'tutor', -- :Tutor command
        'zipPlugin', -- editing zip archives
      },
    },
  },

  -- UI: fallback icons for non-nerd-font terminals
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
}

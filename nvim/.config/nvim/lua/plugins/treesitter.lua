-- Treesitter: syntax parsing for better highlighting, indentation, and code understanding
-- Parsers are auto-installed; powers many other plugins (autotag, textobjects, etc.)
return {
  -- Core treesitter
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate', -- update parsers on install
    main = 'nvim-treesitter.configs',
    opts = {
      ensure_installed = {
        'bash', 'html', 'css', 'graphql',
        'javascript', 'typescript', 'tsx', 'json', 'json5',
        'lua', 'luadoc', 'markdown', 'vim',
        'go', 'gomod', 'gowork', 'gosum',
        'git_config', 'haskell', 'sql', 'python', 'toml', 'ruby', 'regex', 'latex',
      },
      auto_install = true, -- install missing parsers on file open
      highlight = { enable = true, additional_vim_regex_highlighting = false },
      indent = { enable = true }, -- treesitter-based indentation
    },
  },

  -- Treesitter-context: show function/class context at top of window
  -- Toggle: <leader>ut
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPost', 'BufWritePost', 'BufNewFile' },
    opts = function()
      local tsc = require 'treesitter-context'
      Snacks.toggle({
        name = 'Treesitter Context',
        get = tsc.enabled,
        set = function(state)
          if state then tsc.enable() else tsc.disable() end
        end,
      }):map '<leader>ut'
      return { mode = 'cursor', max_lines = 3 }
    end,
  },

  -- Treewalker: navigate AST nodes with Alt+hjkl
  -- Move between sibling nodes, into/out of parent nodes
  {
    'aaronik/treewalker.nvim',
    event = 'VeryLazy',
    keys = {
      { '<A-j>', '<cmd>Treewalker Down<CR>', mode = { 'n', 'v' }, desc = 'Treewalker Down' },
      { '<A-k>', '<cmd>Treewalker Up<CR>', mode = { 'n', 'v' }, desc = 'Treewalker Up' },
      { '<A-h>', '<cmd>Treewalker Left<CR>', mode = { 'n', 'v' }, desc = 'Treewalker Left' },
      { '<A-l>', '<cmd>Treewalker Right<CR>', mode = { 'n', 'v' }, desc = 'Treewalker Right' },
    },
    opts = { highlight = true, highlight_duration = 100, highlight_group = 'Highlight' },
  },
}

return {
  {

    -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = {
        'bash',
        'html',
        'css',
        'graphql',
        'javascript',
        'typescript',
        'tsx',
        'json',
        'json5',
        'lua',
        'luadoc',
        'markdown',
        'vim',
        'go',
        'gomod',
        'gowork',
        'gosum',
        'git_config',
        'haskell',
        'sql',
        'python',
        'toml',
        'ruby',
        'regex',
        'latex',
      },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = false,
      },
      indent = { enable = true },
    },
    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = {
      'BufReadPost',
      'BufWritePost',
      'BufNewFile',
    },
    opts = function()
      local tsc = require 'treesitter-context'
      Snacks.toggle({
        name = 'Treesitter Context',
        get = tsc.enabled,
        set = function(state)
          if state then
            tsc.enable()
          else
            tsc.disable()
          end
        end,
      }):map '<leader>ut'
      return { mode = 'cursor', max_lines = 3 }
    end,
  },
  {
    'aaronik/treewalker.nvim',
    event = 'VeryLazy',
    keys = {
      {
        '<A-j>',
        '<cmd>Treewalker Down<CR>',
        mode = { 'n', 'v' },
        desc = 'Treewalker Down',
      },
      {
        '<A-k>',
        '<cmd>Treewalker Up<CR>',
        mode = { 'n', 'v' },
        desc = 'Treewalker Up',
      },
      {
        '<A-h>',
        '<cmd>Treewalker Left<CR>',
        mode = { 'n', 'v' },
        desc = 'Treewalker Left',
      },
      {
        '<A-l>',
        '<cmd>Treewalker Right<CR>',
        mode = { 'n', 'v' },
        desc = 'Treewalker Right',
      },
    },
    opts = {
      highlight = true,
      highlight_duration = 100,
      highlight_group = 'Highlight',
    },
  },
}

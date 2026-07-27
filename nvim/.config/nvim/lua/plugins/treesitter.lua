-- Treesitter: syntax parsing for highlighting, indentation, and code understanding
return {
  -- Core treesitter (0.12: main branch, parser installer only)
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').setup()

      local parsers = {
        'bash', 'html', 'css', 'graphql',
        'javascript', 'typescript', 'tsx', 'json', 'json5',
        'lua', 'luadoc', 'markdown', 'vim',
        'go', 'gomod', 'gowork', 'gosum',
        'git_config', 'haskell', 'sql', 'python', 'toml', 'ruby', 'regex', 'latex', 'yaml',
      }

      local installed = require('nvim-treesitter').get_installed()
      local to_install = vim.tbl_filter(function(p)
        return not vim.tbl_contains(installed, p)
      end, parsers)
      if #to_install > 0 then
        require('nvim-treesitter').install(to_install)
      end

      -- Highlighting + indentation via native treesitter (not plugin)
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
        callback = function()
          pcall(vim.treesitter.start)
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },

  -- Treesitter-context: show function/class context at top of window
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
  {
    'aaronik/treewalker.nvim',
    keys = {
      { '<A-j>', '<cmd>Treewalker Down<CR>', mode = { 'n', 'v' }, desc = 'Treewalker Down' },
      { '<A-k>', '<cmd>Treewalker Up<CR>', mode = { 'n', 'v' }, desc = 'Treewalker Up' },
      { '<A-h>', '<cmd>Treewalker Left<CR>', mode = { 'n', 'v' }, desc = 'Treewalker Left' },
      { '<A-l>', '<cmd>Treewalker Right<CR>', mode = { 'n', 'v' }, desc = 'Treewalker Right' },
    },
    opts = { highlight = true, highlight_duration = 100, highlight_group = 'Highlight' },
  },
}

-- Gitsigns: git integration for buffers
-- A "hunk" is a contiguous block of changed lines (added, modified, or deleted)
return {
  'lewis6991/gitsigns.nvim',
  event = { 'BufReadPost', 'BufNewFile' },
  opts = {
    signs = {
      add = { text = '+' },
      change = { text = '~' },
      delete = { text = '_' },
      topdelete = { text = '‾' },
      changedelete = { text = '~' },
    },
    on_attach = function(bufnr)
      local gitsigns = require 'gitsigns'

      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
      end

      -- Navigation: jump between hunks
      map('n', ']c', function()
        if vim.wo.diff then
          vim.cmd.normal { ']c', bang = true }
        else
          gitsigns.nav_hunk 'next'
        end
      end, { desc = 'Next hunk' })

      map('n', '[c', function()
        if vim.wo.diff then
          vim.cmd.normal { '[c', bang = true }
        else
          gitsigns.nav_hunk 'prev'
        end
      end, { desc = 'Prev hunk' })

      -- Staging: add changes to git index
      map('v', '<leader>hs', function()
        gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
      end, { desc = 'Stage selected lines' })
      map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'Stage hunk under cursor' })
      map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'Stage entire buffer' })
      map('n', '<leader>hu', gitsigns.undo_stage_hunk, { desc = 'Undo last staged hunk' })

      -- Reset: discard changes
      map('v', '<leader>hr', function()
        gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
      end, { desc = 'Reset selected lines' })
      map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'Reset hunk under cursor' })
      map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'Reset entire buffer' })

      -- View: preview and inspect changes
      map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'Preview hunk in popup' })
      map('n', '<leader>hb', gitsigns.blame_line, { desc = 'Show blame for current line' })
      map('n', '<leader>hd', gitsigns.diffthis, { desc = 'Diff against index' })
      map('n', '<leader>hD', function()
        gitsigns.diffthis '@'
      end, { desc = 'Diff against last commit' })

      -- Toggles
      map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = 'Toggle inline blame' })
      map('n', '<leader>tD', gitsigns.preview_hunk_inline, { desc = 'Toggle deleted lines inline' })
    end,
  },
}

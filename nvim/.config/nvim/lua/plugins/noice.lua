-- Noice: replaces vim's UI for messages, cmdline, and popupmenu
-- Renders notifications in floating windows, cmdline as popup, search at bottom
-- Uses treesitter for syntax highlighting in LSP docs and signatures
return {
  'folke/noice.nvim',
  event = 'VeryLazy', -- load after startup
  dependencies = {
    'MunifTanjim/nui.nvim', -- UI component library
    'rcarriga/nvim-notify', -- notification manager
  },
  opts = {
    -- LSP Integration
    lsp = {
      override = {
        -- use treesitter for markdown rendering in LSP popups
        ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
        ['vim.lsp.util.stylize_markdown'] = true,
        ['cmp.entry.get_documentation'] = true,
      },
      signature = {
        enabled = true,
        auto_open = {
          enabled = true,
          trigger = true, -- show on trigger chars (e.g., '(' for functions)
          luasnip = true, -- show when jumping to snippet nodes
          throttle = 100, -- debounce (ms)
        },
      },
      hover = { enabled = true, silent = true },
    },

    -- Presets: pre-configured UI layouts
    presets = {
      bottom_search = true, -- classic search at bottom
      command_palette = true, -- cmdline + popupmenu together
      long_message_to_split = true, -- overflow messages open in split
      inc_rename = false, -- inc-rename.nvim dialog
      lsp_doc_border = true, -- borders on hover/signature
    },
  },
  config = function(_, opts)
    -- clear messages when lazy.nvim is installing (avoids noise)
    if vim.o.filetype == 'lazy' then
      vim.cmd [[messages clear]]
    end
    require('noice').setup(opts)
  end,
}

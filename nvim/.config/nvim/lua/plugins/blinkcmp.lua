-- Blink.cmp: fast completion engine written in Rust
-- Provides autocomplete suggestions as you type from LSP, buffer, path
-- Keymaps: C-y accept, C-n/C-p navigate, C-space open menu, C-e hide, C-k signature
return {
  'saghen/blink.cmp',
  dependencies = {
    'xzbdmw/colorful-menu.nvim', -- syntax-highlighted completion menu
  },
  version = '*', -- use latest release (pre-built binaries)

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    -- Keymaps: 'default' uses C-y to accept (like vim's built-in completion)
    keymap = { preset = 'default' },

    -- Signature Help: disabled, noice.nvim handles this
    signature = { enabled = false },

    -- Appearance
    appearance = {
      use_nvim_cmp_as_default = false,
      nerd_font_variant = 'mono', -- icon spacing for monospace nerd fonts
    },

    -- Completion Behavior
    completion = {
      accept = {
        auto_brackets = { enabled = true }, -- add () after functions
      },
      documentation = { auto_show = true }, -- show docs popup automatically
      ghost_text = { enabled = true }, -- preview completion inline (grayed out)
      menu = {
        draw = {
          treesitter = { 'lsp' }, -- syntax highlight LSP items
          columns = { { 'kind_icon' }, { 'label', gap = 1 } },
          components = {
            -- colorful-menu provides syntax-highlighted labels
            label = {
              text = function(ctx)
                return require('colorful-menu').blink_components_text(ctx)
              end,
              highlight = function(ctx)
                return require('colorful-menu').blink_components_highlight(ctx)
              end,
            },
          },
        },
      },
    },

    -- Completion Sources (in priority order)
    sources = {
      default = { 'lazydev', 'lsp', 'path', 'buffer' },
      providers = {
        lazydev = {
          name = 'LazyDev',
          module = 'lazydev.integrations.blink',
          score_offset = 100, -- prioritize neovim API completions
        },
      },
    },

    -- Fuzzy Matching: Rust implementation for speed and typo tolerance
    fuzzy = { implementation = 'rust' },

    -- Command Line: completion in : and / modes
    cmdline = {
      completion = {
        menu = { auto_show = true },
        ghost_text = { enabled = true },
      },
    },
  },
  opts_extend = { 'sources.default' }, -- allow extending sources from other configs
}

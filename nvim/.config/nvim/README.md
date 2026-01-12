# Neovim Config

## Structure

```
nvim/.config/nvim/
├── init.lua                 # Entry point, loads config modules
├── lua/
│   ├── config/
│   │   ├── options.lua      # Vim options (line numbers, tabs, etc.)
│   │   ├── keymap.lua       # Global keymaps and leader key
│   │   ├── autocmds.lua     # Auto-commands (format on save, etc.)
│   │   └── lazy.lua         # Plugin manager setup
│   └── plugins/             # Plugin configs (one file per plugin/group)
└── after/ftplugin/          # Filetype-specific settings
```

## Key Files

| File | Purpose |
|------|---------|
| `config/options.lua` | Editor behavior: tabs, search, scrolling, UI |
| `config/keymap.lua` | Leader key (space), window nav, quick actions |
| `config/autocmds.lua` | Auto-reload files, resize splits, filetype settings |
| `config/lazy.lua` | Plugin manager bootstrap and configuration |

## Plugins

| Plugin | Description | Key Bindings |
|--------|-------------|--------------|
| **autopairs** | Auto-close brackets, quotes | Automatic |
| **autotag** | Auto-close/rename HTML/JSX tags | Automatic |
| **blinkcmp** | Completion engine | `C-y` accept, `C-n/p` navigate, `C-space` open |
| **colorscheme** | Gruvbox-material theme | - |
| **conform** | Code formatter | `<leader>f` format, auto on save |
| **dropbar** | Breadcrumb navigation | `<leader>;` pick, `[;` `];` navigate |
| **gitsigns** | Git signs + actions | `]c` `[c` hunks, `<leader>h*` stage/reset |
| **lazydev** | Lua LSP for nvim config | Automatic |
| **lazygit** | Git TUI | `<leader>lg` |
| **mini** | ai, surround, statusline | `sa` `sd` `sr` surround, `va)` `ci'` textobjects |
| **noice** | UI for messages/cmdline | Automatic |
| **nvim-lspconfig** | LSP setup | `<leader>rn` rename, `<leader>ca` action, `gd` `gr` goto |
| **render-markdown** | Prettify markdown | Automatic |
| **sidekick** | AI assistant | `<C-.>` toggle, `<leader>a*` send context |
| **snacks** | Picker, explorer, etc. | `<leader><space>` find, `<leader>/` grep, `<leader>e` explorer |
| **tiny-inline-diagnostic** | Pretty diagnostics | Automatic |
| **treesitter** | Syntax parsing | `<A-hjkl>` treewalker, `<leader>ut` toggle context |
| **trouble** | Diagnostics list | `<leader>xx` diagnostics, `[q` `]q` navigate |
| **utils** | Sleuth + todo-comments | Automatic indent detection |
| **which-key** | Keymap popup | Press `<leader>` and wait |

## Common Keymaps

### Leader Key: `<Space>`

**Files & Search**
- `<leader><space>` - Smart file finder
- `<leader>/` - Grep search
- `<leader>e` - File explorer
- `<leader>ff` - Find files
- `<leader>fg` - Find git files
- `<leader>fr` - Recent files

**Git**
- `<leader>lg` - Lazygit
- `<leader>gs` - Git status
- `<leader>gb` - Git branches
- `<leader>hs` - Stage hunk
- `<leader>hr` - Reset hunk
- `<leader>hb` - Blame line

**LSP**
- `gd` - Go to definition
- `gr` - References
- `gI` - Implementations
- `<leader>rn` - Rename
- `<leader>ca` - Code action

**Diagnostics**
- `<leader>xx` - All diagnostics
- `<leader>xX` - Buffer diagnostics
- `[d` `]d` - Prev/next diagnostic

**Buffers**
- `<leader>,` - Buffer list
- `<leader>bd` - Delete buffer
- `<leader>bn` `<leader>bp` - Next/prev buffer

**Toggles** (`<leader>u*`)
- `<leader>us` - Spell
- `<leader>uw` - Wrap
- `<leader>ud` - Diagnostics
- `<leader>uh` - Inlay hints
- `<leader>ut` - Treesitter context

**Other**
- `<leader>w` - Save
- `<leader>q` - Quit
- `<leader>z` - Zen mode
- `jk` - Exit insert mode

### Navigation

- `C-h/j/k/l` - Window navigation
- `C-d` `C-u` - Half-page scroll (centered)
- `]c` `[c` - Next/prev git hunk
- `]]` `[[` - Next/prev reference
- `<A-hjkl>` - Treewalker (AST navigation)

## Adding Plugins

1. Create a new file in `lua/plugins/` (e.g., `lua/plugins/myplugin.lua`)
2. Return a lazy.nvim plugin spec:

```lua
-- Description of what the plugin does
return {
  'author/plugin-name',
  opts = {},
}
```

3. Restart neovim or run `:Lazy`

## Commands

- `:Lazy` - Plugin manager UI
- `:Mason` - LSP/tool installer
- `:checkhealth` - Diagnose issues
- `:ConformInfo` - Active formatters
- `:LspInfo` - Active LSP servers

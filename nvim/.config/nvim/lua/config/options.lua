-- Fonts & Colors
vim.g.have_nerd_font = true -- enable nerd font icons throughout config
-- Line Numbers
vim.opt.relativenumber = true -- show relative line numbers for easy jumping (e.g., 5j)

-- Mode Display
vim.opt.showmode = false -- hide mode text (e.g., "-- INSERT --"), statusline handles it

-- Clipboard
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus' -- use system clipboard for yank/paste (scheduled to avoid startup delay)
end)

-- Indentation
vim.opt.tabstop = 4 -- number of spaces a <Tab> counts for
vim.opt.softtabstop = 4 -- number of spaces for <Tab> in editing operations
vim.opt.shiftwidth = 4 -- number of spaces for each indent level
vim.opt.expandtab = true -- convert tabs to spaces
-- Line Wrapping
vim.opt.wrap = false -- don't wrap long lines (scroll horizontally instead)

-- File Backup & Undo
vim.opt.swapfile = false -- don't create swap files (prevents .swp clutter)
vim.opt.backup = false -- don't create backup files
vim.opt.undodir = os.getenv 'HOME' .. '/.vim/undodir' -- persistent undo history location
vim.opt.undofile = true -- save undo history to file (persists across sessions)

-- Search
vim.opt.hlsearch = true -- highlight search matches, <Esc> clears
vim.opt.ignorecase = true -- case-insensitive search by default
vim.opt.smartcase = true -- case-sensitive if search contains uppercase
-- Scrolling & Cursor
vim.opt.scrolloff = 8 -- keep 8 lines visible above/below cursor when scrolling
vim.opt.sidescrolloff = 8 -- keep 8 columns visible left/right of cursor

-- Window Splits
vim.opt.splitright = true -- open vertical splits to the right
vim.opt.splitbelow = true -- open horizontal splits below

-- Timing
vim.opt.updatetime = 50 -- faster CursorHold events (default 4000ms), improves responsiveness
vim.opt.timeoutlen = 300 -- time to wait for mapped sequence (ms), affects which-key popup

-- Whitespace Display
vim.opt.list = true -- show invisible characters
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' } -- symbols for tab, trailing space, non-breaking space

-- Syntax (disabled, treesitter handles highlighting)
vim.opt.syntax = 'off'
vim.cmd.syntax 'manual'

-- Folding
vim.opt.foldenable = false -- start with all folds open

-- Spell Check
vim.opt.spell = false -- disable spell checking by default
vim.opt.spellcapcheck = '' -- disable capitalization warnings
vim.opt.spellfile = {
  vim.fn.stdpath('config') .. '/spell/en.utf-8.add', -- 1zg: personal
  vim.fn.stdpath('config') .. '/spell/en.work.utf-8.add', -- 2zg: work
}

-- LSP Logging (enable for debugging, impacts performance)
--vim.lsp.set_log_level 'on'

-- Matchparen Performance
vim.g.matchparen_timeout = 2 -- timeout (ms) for matching parens highlighting
vim.g.matchparen_insert_timeout = 2 -- timeout in insert mode (prevents lag on large files)

-- Statusline
vim.opt.laststatus = 3 -- global statusline (single bar across all windows)

-- Line Breaking
vim.opt.linebreak = true -- when wrap is on, break at word boundaries (not mid-word)
vim.g.markdown_recommended_style = 0 -- disable default markdown indent style

-- Icons (used by various plugins for consistent iconography)
vim.g.icons = {
  misc = {
    dots = '󰇘',
  },
  ft = {
    octo = '',
  },
  dap = {
    Stopped = { '󰁕 ', 'DiagnosticWarn', 'DapStoppedLine' },
    Breakpoint = ' ',
    BreakpointCondition = ' ',
    BreakpointRejected = { ' ', 'DiagnosticError' },
    LogPoint = '.>',
  },
  diagnostics = {
    Error = ' ',
    Warn = ' ',
    Hint = ' ',
    Info = ' ',
  },
  git = {
    added = ' ',
    modified = ' ',
    removed = ' ',
  },
  kinds = {
    Array = ' ',
    Boolean = '󰨙 ',
    Class = ' ',
    Codeium = '󰘦 ',
    Color = ' ',
    Control = ' ',
    Collapsed = ' ',
    Constant = '󰏿 ',
    Constructor = ' ',
    Copilot = ' ',
    Enum = ' ',
    EnumMember = ' ',
    Event = ' ',
    Field = ' ',
    File = ' ',
    Folder = ' ',
    Function = '󰊕 ',
    Interface = ' ',
    Key = ' ',
    Keyword = ' ',
    Method = '󰊕 ',
    Module = ' ',
    Namespace = '󰦮 ',
    Null = ' ',
    Number = '󰎠 ',
    Object = ' ',
    Operator = ' ',
    Package = ' ',
    Property = ' ',
    Reference = ' ',
    Snippet = '󱄽 ',
    String = ' ',
    Struct = '󰆼 ',
    Supermaven = ' ',
    TabNine = '󰏚 ',
    Text = ' ',
    TypeParameter = ' ',
    Unit = ' ',
    Value = ' ',
    Variable = '󰀫 ',
  },
}

-- Treesitter: treat zsh files as bash for syntax highlighting
vim.treesitter.language.register('bash', 'zsh')

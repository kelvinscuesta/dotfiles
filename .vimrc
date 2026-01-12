" =============================================================================
" Vimrc - synced with neovim config (lua/config/options.lua & keymap.lua)
" =============================================================================

" -----------------------------------------------------------------------------
" Leader Key
" -----------------------------------------------------------------------------
" Space as leader key - used as prefix for custom keybindings
let mapleader = " "
let maplocalleader = " "

" -----------------------------------------------------------------------------
" Colors
" -----------------------------------------------------------------------------
" Enable 24-bit RGB colors in the terminal (requires terminal support)
if (has("termguicolors"))
  set termguicolors
endif

" -----------------------------------------------------------------------------
" Line Numbers
" -----------------------------------------------------------------------------
" Show absolute line number on current line
set number
" Show relative line numbers for easy jumping (5j, 10k, etc.)
set relativenumber

" -----------------------------------------------------------------------------
" Mouse
" -----------------------------------------------------------------------------
" Enable mouse support in all modes (normal, visual, insert, command)
set mouse=a

" -----------------------------------------------------------------------------
" Status Line
" -----------------------------------------------------------------------------
" Hide mode indicator (-- INSERT --) since statusline plugins show it
set noshowmode
" Always show status line (0=never, 1=only with splits, 2=always)
set laststatus=2

" -----------------------------------------------------------------------------
" Clipboard
" -----------------------------------------------------------------------------
" Use system clipboard for all yank/delete/paste operations
" Allows seamless copy/paste between vim and other applications
set clipboard=unnamedplus

" -----------------------------------------------------------------------------
" Tabs and Indentation
" -----------------------------------------------------------------------------
" Number of spaces a <Tab> counts for when displaying
set tabstop=4
" Number of spaces a <Tab> counts for when editing (insert/delete)
set softtabstop=4
" Number of spaces for each step of auto-indent (>>, <<, etc.)
set shiftwidth=4
" Convert tabs to spaces when inserting
set expandtab
" Smart auto-indenting when starting a new line
set smartindent

" -----------------------------------------------------------------------------
" Line Wrapping
" -----------------------------------------------------------------------------
" Don't wrap long lines - scroll horizontally instead
set nowrap
" If wrap is enabled, break at word boundaries (not mid-word)
set linebreak

" -----------------------------------------------------------------------------
" Backup and Undo
" -----------------------------------------------------------------------------
" Disable swap files (the .swp files that vim creates)
set noswapfile
" Disable backup files (the ~ files)
set nobackup
" Directory to store persistent undo history
set undodir=~/.vim/undodir
" Enable persistent undo - survives closing and reopening vim
set undofile

" -----------------------------------------------------------------------------
" Search
" -----------------------------------------------------------------------------
" Don't highlight all search matches (use <Esc> to clear if needed)
set nohlsearch
" Show matches as you type the search pattern
set incsearch
" Case-insensitive search by default
set ignorecase
" Case-sensitive if search contains uppercase letters
set smartcase

" -----------------------------------------------------------------------------
" Scroll Behavior
" -----------------------------------------------------------------------------
" Keep 8 lines visible above/below cursor when scrolling vertically
set scrolloff=8
" Keep 8 columns visible left/right of cursor when scrolling horizontally
set sidescrolloff=8

" -----------------------------------------------------------------------------
" UI Elements
" -----------------------------------------------------------------------------
" Always show the sign column (used for git signs, diagnostics, etc.)
" Prevents layout shift when signs appear/disappear
set signcolumn=yes
" Highlight the current line the cursor is on
set cursorline

" -----------------------------------------------------------------------------
" Window Splits
" -----------------------------------------------------------------------------
" Open vertical splits to the right of current window
set splitright
" Open horizontal splits below current window
set splitbelow

" -----------------------------------------------------------------------------
" Performance
" -----------------------------------------------------------------------------
" Time in ms to wait before triggering CursorHold event (affects plugins)
" Lower = more responsive, but more CPU usage
set updatetime=50
" Time in ms to wait for a mapped sequence to complete
" Lower = snappier, but less time to type multi-key mappings
set timeoutlen=300

" -----------------------------------------------------------------------------
" Whitespace Visualization
" -----------------------------------------------------------------------------
" Show invisible characters
set list
" Define how to display invisible characters:
"   tab:»   = tabs shown as »
"   trail:· = trailing spaces shown as ·
"   nbsp:␣  = non-breaking spaces shown as ␣
set listchars=tab:»\ ,trail:·,nbsp:␣

" -----------------------------------------------------------------------------
" Folding
" -----------------------------------------------------------------------------
" Disable code folding by default (can still fold manually)
set nofoldenable

" =============================================================================
" KEY MAPPINGS
" =============================================================================

" -----------------------------------------------------------------------------
" Disabled Keys
" -----------------------------------------------------------------------------
" Disable Ex mode (confusing for most users, rarely needed)
nnoremap Q <Nop>

" -----------------------------------------------------------------------------
" Navigation
" -----------------------------------------------------------------------------
" Scroll down half page and center cursor on screen
nnoremap <C-d> <C-d>zz
" Scroll up half page and center cursor on screen
nnoremap <C-u> <C-u>zz

" -----------------------------------------------------------------------------
" Window Navigation
" -----------------------------------------------------------------------------
" Move focus between split windows using Ctrl + hjkl
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" -----------------------------------------------------------------------------
" Search
" -----------------------------------------------------------------------------
" Clear search highlighting with Escape
nnoremap <Esc> :nohlsearch<CR>

" -----------------------------------------------------------------------------
" File Operations
" -----------------------------------------------------------------------------
" Quick save with <leader>w
nnoremap <leader>w :w!<CR>
" Quick quit with <leader>q
nnoremap <leader>q :q<CR>

" -----------------------------------------------------------------------------
" Insert Mode
" -----------------------------------------------------------------------------
" Exit insert mode by typing 'jk' quickly (easier than reaching for Escape)
inoremap jk <Esc>

" -----------------------------------------------------------------------------
" Buffer Navigation
" -----------------------------------------------------------------------------
" Go to next buffer
nnoremap <leader>bn :bnext<CR>
" Go to previous buffer
nnoremap <leader>bp :bprevious<CR>
" Close/delete current buffer
nnoremap <leader>bd :bdelete<CR>
" Switch to last used buffer (toggle between two buffers)
nnoremap <leader>bl :b#<CR>

" =============================================================================
" AUTOCOMMANDS
" =============================================================================

" -----------------------------------------------------------------------------
" Yank Highlight
" -----------------------------------------------------------------------------
" Briefly highlight yanked text (only works in neovim, ignored in vim)
augroup YankHighlight
  autocmd!
  autocmd TextYankPost * silent! lua vim.highlight.on_yank()
augroup END

" =============================================================================
" INITIALIZATION
" =============================================================================

" Create undo directory if it doesn't exist
if !isdirectory(expand("~/.vim/undodir"))
  call mkdir(expand("~/.vim/undodir"), "p")
endif

" Basic Settings

" Disable Vi compatibility mode
set nocompatible

" Enable syntax highlighting
syntax on

" Set history to remember 500 lines
set history=500

" Disable the default Vim startup message
set shortmess+=I

" Set the height of the command bar
set cmdheight=1

" No annoying sound on errors
set noerrorbells visualbell t_vb=
autocmd GUIEnter * set visualbell t_vb=
set tm=500

" Always show the status line
set laststatus=2
set noshowmode

" Use UTF-8 encoding
set encoding=utf-8

" Set language and menu to English
let $LANG='en'
set langmenu=en

" Use Unix as the standard file type
set ffs=unix,dos,mac


"Use 24-bit (true-color) mode in Vim/Neovim when outside tmux.
"If you're using tmux version 2.2 or later, you can remove the outermost $TMUX check and use tmux's 24-bit color support
"(see < http://sunaku.github.io/tmux-24bit-color.html#usage > for more information.)
if (empty($TMUX) && getenv('TERM_PROGRAM') != 'Apple_Terminal')
  if (has("nvim"))
    "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  endif
  "For Neovim > 0.1.5 and Vim > patch 7.4.1799 < https://github.com/vim/vim/commit/61be73bb0f965a895bfb064ea3e55476ac175162 >
  "Based on Vim patch 7.4.1770 (`guicolors` option) < https://github.com/vim/vim/commit/8a633e3427b47286869aa4b96f2bfc1fe65b25cd >
  " < https://github.com/neovim/neovim/wiki/Following-HEAD#20160511 >
  if (has("termguicolors"))
    set termguicolors
  endif
endif


set background=dark    

" Colorscheme and lightline configuration
colorscheme gruvbox

let g:lightline = {
      \ 'colorscheme': 'gruvbox',
      \ }
" Search and Navigation

" Enable case-insensitive search unless uppercase is used
set ignorecase
set smartcase

" Enable incremental search
set incsearch

" Show matching brackets
set showmatch

" Set bracket match blink time
set mat=2

" Set 7 lines of context around the cursor
set so=7

" Turn on the Wild menu
set wildmenu
set wildmode=list:longest,list:full


" Text, Tab, and Indent Settings

" Expand tabs to spaces
set expandtab

" Be smart with tabs
set smarttab

" 1 tab = 4 spaces
set shiftwidth=4
set tabstop=4

" Enable auto and smart indenting
set ai
set si

" Enable line wrapping and break on 500 characters
set wrap
set lbr
set tw=500

" Display the ruler
set ruler


" File and Buffer Management

" Turn off backups and swapfiles
set nobackup
set nowb
set noswapfile

" Enable hidden buffers
set hidden
set hid

" Enable autoread for external file changes
set autoread
au FocusGained,BufEnter * silent! checktime


" Interface and Appearance

" Show line numbers and relative line numbers
set number
set relativenumber

" Set showtabline to always display the tab bar
set showtabline=2

" Handle window splitting
set splitright
set splitbelow

" Disable redraw during macro execution
set lazyredraw


" Key Mappings and Leader Commands

" Unbind annoying default keys
nmap Q <Nop>

" Map leader key to space
let mapleader = " "

" Fast save using leader key
nmap <leader>w :w!<CR>

" Command for sudo save
command! W execute 'w !sudo tee % > /dev/null' <bar> edit!

" Map jk to escape in insert mode
inoremap jk <esc>

" Prevent bad habits with arrow keys
nnoremap <Left>  :echoe "Use h"<CR>
nnoremap <Right> :echoe "Use l"<CR>
nnoremap <Up>    :echoe "Use k"<CR>
nnoremap <Down>  :echoe "Use j"<CR>
inoremap <Left>  <ESC>:echoe "Use h"<CR>
inoremap <Right> <ESC>:echoe "Use l"<CR>
inoremap <Up>    <ESC>:echoe "Use k"<CR>
inoremap <Down>  <ESC>:echoe "Use j"<CR>

" Remap ctrl + w hjkl to ctrl hjkl to move between windows
nnoremap <C-H> <C-W>h
nnoremap <C-J> <C-W>j
nnoremap <C-K> <C-W>k
nnoremap <C-L> <C-W>l


"" Buffer key binds

" toggle buffer (switch between current and last buffer)
nnoremap <silent> <leader>bb <C-^>

" go to next buffer
nnoremap <silent> <leader>bn :bn<CR>
nnoremap <C-l> :bn<CR>

" go to previous buffer
nnoremap <silent> <leader>bp :bp<CR>

" https://github.com/neovim/neovim/issues/2048
nnoremap <C-h> :bp<CR>

" close buffer
nnoremap <silent> <leader>bd :bd<CR>

" kill buffer
nnoremap <silent> <leader>bk :bd!<CR>

" list buffers
nnoremap <silent> <leader>bl :ls<CR>
" list and select buffer
nnoremap <silent> <leader>bg :ls<CR>:buffer<Space>

" horizontal split with new buffer
nnoremap <silent> <leader>bh :new<CR>

" vertical split with new buffer
nnoremap <silent> <leader>bv :vnew<CR>

" Add a remap for quitting with the leader
nnoremap <leader>q :q<CR>

" Miscellaneous

" Enable mouse support
set mouse+=a

" Enable magic mode for regex
set magic

" Configure backspace behavior
set backspace=indent,eol,start

" Set file-specific plugins and indentation
filetype plugin on
filetype indent on

" fzf runtime path
" If installed using Homebrew
set rtp+=/usr/local/opt/fzf


" set ripgrep if it exists as the :grep command 
if executable('rg')
    set grepprg=rg\ --vimgrep\ --no-heading\ --smart-case
    set grepformat=%f:%l:%c:%m,%f:%l:%m
endif


" Find files in the current directory
nnoremap <leader>ff :Files<CR>

" Search for content in files (live grep)
nnoremap <leader>fg :Rg<CR>


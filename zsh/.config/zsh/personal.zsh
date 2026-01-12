# Personal shell configuration

# Editor
export VISUAL=nvim
export EDITOR="$VISUAL"

# Aliases - editor
alias vim='nvim'
alias nvimconfig='nvim ~/.config/nvim/'
alias zshconfig='nvim ~/.zshrc'
alias ghosttyConfig='nvim ~/Library/Application\ Support/com.mitchellh.ghostty/config'

# Aliases - file navigation
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias cat='bat'

# Aliases - git
alias g='git'
alias gst='git status'
alias ga='git add'
alias gco='git checkout'
alias gc='git commit'
alias gl='git pull --rebase --prune'
alias gdh='git diff HEAD'
alias gpom='git pull origin main'
alias lg='lazygit'
alias root='cd $(git rev-parse --show-toplevel)'

# Aliases - tools
alias lzd='lazydocker'
alias runkmonad='sudo ~/kmonadbin ~/.kmonad.kbd'

# Pager
export MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\\x08//g\" | bat -p -lman'"

# Interactive ripgrep with fzf
rgf() (
  RELOAD='reload:rg --column --color=always --smart-case {q} || :'
  OPENER='if [[ $FZF_SELECT_COUNT -eq 0 ]]; then
            vim {1} +{2}     # No selection. Open the current line in Vim.
          else
            vim +cw -q {+f}  # Build quickfix list for the selected items.
          fi'
  fzf --disabled --ansi --multi \
      --bind "start:$RELOAD" --bind "change:$RELOAD" \
      --bind "enter:become:$OPENER" \
      --bind "ctrl-o:execute:$OPENER" \
      --bind 'alt-a:select-all,alt-d:deselect-all,ctrl-/:toggle-preview' \
      --delimiter : \
      --preview 'bat --style=full --color=always --highlight-line {2} {1}' \
      --preview-window '~4,+{2}+4/3,<80(up)' \
      --query "$*"
)

# Starship prompt
eval "$(starship init zsh)"

# Haskell (ghcup)
[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"

# Local bin
. "$HOME/.local/bin/env"

# Mise (version manager)
eval "$(mise activate zsh)"

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
alias md='mdcat -p'

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

# Aliases - claude
alias cdc='cd ~/.claude'
alias cdcp='cd ~/.claude/plans'
alias cdcr='cd ~/.claude/research'

# Aliases - shell
alias reload='exec zsh'

# Aliases - tools
alias lzd='lazydocker'
alias runkmonad='sudo ~/kmonadbin ~/.kmonad.kbd'
alias tmux-guide='open ~/dotfiles/tmux/tmux-guide.html'

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
export PATH="$HOME/.local/bin:$PATH"

# Mise (version manager)
eval "$(mise activate zsh)"

# -----------------
# tmux autostart
# -----------------
# Auto-attach (or auto-create) tmux session when opening an interactive shell.
# Pairs with tmux-continuum (@continuum-restore on) to restore last saved
# session after reboot.
#
# Conditions:
#   $TMUX empty             → not already inside tmux (prevents nesting)
#   $- contains 'i'         → interactive shell only (skip scripts/cron)
#   $NO_TMUX unset          → user opt-out: `NO_TMUX=1 zsh` for plain shell
#   $TERM_PROGRAM=ssh-skip  → if you want SSH to skip, set in ssh config
#
# Behavior:
#   tmux attach             → connects to existing session if any
#   ||                      → fall-through on failure (no session yet)
#   tmux new-session        → creates fresh session; continuum auto-restores
#                             from last save if @continuum-restore is on
#
# To bypass on demand:
#   NO_TMUX=1 ghostty       → opens terminal without tmux
#   command zsh             → spawns plain zsh inside an existing tmux pane
if [[ -z "$TMUX" ]] && [[ $- == *i* ]] && [[ -z "$NO_TMUX" ]]; then
  tmux attach 2>/dev/null || tmux new-session
fi

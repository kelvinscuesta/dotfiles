# Zsh configuration

# History
setopt HIST_IGNORE_ALL_DUPS

# Keybindings (emacs style)
bindkey -e

# Word characters (exclude path separator)
WORDCHARS=${WORDCHARS//[\/]}

# -----------------
# Zim module config
# -----------------

ZSH_AUTOSUGGEST_MANUAL_REBIND=1
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# -----------------
# Zim initialization
# -----------------

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim

# Download zimfw if missing
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
      https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
fi

# Install/update modules if needed
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]]; then
  source ${ZIM_HOME}/zimfw.zsh init
fi

# Skip compinit check (direnv initializes completions early)
zstyle ':zim:completion' skip-compinit-check yes

# Initialize Zim
source "${ZIM_HOME}/init.zsh"

# Post-init
zmodload -F zsh/terminfo +p:terminfo

# -----------------
# Modular config
# -----------------

[[ -f ~/.config/zsh/personal.zsh ]] && source ~/.config/zsh/personal.zsh
[[ -f ~/.config/zsh/work.zsh ]] && source ~/.config/zsh/work.zsh

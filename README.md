# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Bootstrap a New Mac

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Clone and install
git clone git@github.com:kelvinscuesta/dotfiles.git ~/dotfiles
cd ~/dotfiles
brew bundle

# 3. Stow packages (see package list below)
stow zsh claude codex nvim git ghostty starship bat tmux kanata

# 4. Post-stow setup
./bootstrap.sh

# 5. Install language runtimes via mise
mise install
```

## Packages

### Personal (any machine)

| Package | Contents | Target |
|---------|----------|--------|
| `zsh` | `.zshrc`, `.zimrc`, `personal.zsh` | `~` |
| `claude` | `CLAUDE.md`, skills, hooks, statusline | `~/.claude/` |
| `codex` | `AGENTS.md` (commit/PR standards) | `~/.codex/` |
| `nvim` | Neovim config (lazy.nvim, native LSP, 20+ plugins) | `~/.config/nvim/` |
| `git` | `.gitconfig` (delta, signing, aliases) | `~` |
| `ghostty` | Ghostty terminal + gruvbox-material themes | `~/.config/ghostty/` |
| `starship` | Starship prompt | `~/.config/starship.toml` |
| `bat` | Bat config + Catppuccin themes | `~/.config/bat/` |
| `tmux` | tmux config + plugins | `~/.config/tmux/` |
| `kanata` | Homerow mods (kanata + Karabiner DriverKit) | `~/.config/kanata/` |
| `karabiner` | Karabiner-Elements config | `~/.config/karabiner/` |
| `glove80` | Glove80 keymap (reference, not stowed) | — |

### Work-only (Gusto machine)

| Package | Contents | Extra setup |
|---------|----------|-------------|
| `zsh-work` | `work.zsh` (Gusto repos, AWS, monorepo aliases) | Needs `~/.gusto/init.sh` from Gusto config_files repo |
| `claude-work` | Work settings, MCP servers, workflow automation, skhd hotkeys | Needs `.env` (see below) |

```bash
# Work machine — add these after personal packages:
stow zsh-work claude-work
```

#### Work `.env` setup

```bash
cp ~/.claude/workflow-server/.env.example ~/.claude/workflow-server/.env
# Fill in: SLACK_CHANNEL_ID, JIRA_PROJECT, GITHUB_REPOS, BUILDKITE_API_TOKEN
```

#### Work dependencies not in Brewfile

- `bun` — workflow-server runtime (`curl -fsSL https://bun.sh/install | bash`)
- `acli` — Atlassian CLI (`brew install atlassian/acli/acli`)
- `~/.gusto/init.sh` — clone Gusto's config_files repo

## Structure

```
~/dotfiles/
├── zsh/           # Core zsh + personal config
├── zsh-work/      # Gusto-specific (optional)
├── claude/        # Claude Code personal config
├── claude-work/   # Claude Code work config (optional)
├── codex/         # Codex personal config
├── nvim/          # Neovim (native LSP, treesitter, lazy.nvim)
│   └── .config/nvim/
│       ├── init.lua
│       ├── lsp/         # Native LSP server configs (0.12+)
│       └── lua/plugins/ # Lazy.nvim plugin specs
├── git/           # Git config
├── ghostty/       # Ghostty terminal
├── starship/      # Starship prompt
├── bat/           # Bat (better cat)
├── tmux/          # tmux
├── kanata/        # Keyboard remapping
├── karabiner/     # Karabiner-Elements
├── glove80/       # Glove80 keymap (reference)
├── Brewfile       # Homebrew packages
└── bootstrap.sh   # Post-stow setup (bat themes, zim)
```

## Adding new configs

```bash
mkdir -p ~/dotfiles/newpkg/.config/newpkg
mv ~/.config/newpkg/* ~/dotfiles/newpkg/.config/newpkg/
cd ~/dotfiles && stow newpkg
```

## Notes

- `~/.secrets` not tracked (API keys, tokens)
- `~/.gusto/` managed by Gusto's config_files repo (not here)
- `git [maintenance]` repos are in a local gitconfig include (machine-specific)
- Neovim requires 0.12+ (native LSP, treesitter main branch)
- `tree-sitter-cli` must be on PATH for treesitter parser compilation

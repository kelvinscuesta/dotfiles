# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Quick Start

```bash
# Install dependencies
brew bundle

# Clone repo
git clone <repo-url> ~/dotfiles
cd ~/dotfiles

# Stow all packages (work machine)
stow zsh zsh-work claude claude-work nvim git ghostty starship bat kmonad karabiner

# Personal machine (skip work config)
stow zsh claude nvim git ghostty starship bat kmonad karabiner
```

## Structure

```
~/dotfiles/
├── zsh/           # Core zsh + personal config
├── zsh-work/      # Gusto-specific config (optional)
├── claude/        # Claude Code personal config (CLAUDE.md, skills, hooks)
├── claude-work/   # Claude Code work config (settings.json, work skills)
├── nvim/          # Neovim
├── git/           # Git config
├── ghostty/       # Ghostty terminal
├── starship/      # Starship prompt
├── bat/           # Bat (better cat)
├── kmonad/        # Kmonad keyboard
├── karabiner/     # Karabiner-Elements
└── Brewfile       # Homebrew packages
```

## Packages

| Package | Contents |
|---------|----------|
| `zsh` | `.zshrc`, `.zimrc`, `personal.zsh` |
| `zsh-work` | `work.zsh` (Gusto aliases, AWS, secrets) |
| `claude` | `CLAUDE.md`, statusline, skills, hooks |
| `claude-work` | `settings.json` (Bedrock, plugins), work skills |
| `nvim` | Neovim config |
| `git` | `.gitconfig` |
| `ghostty` | Ghostty terminal config |
| `starship` | Starship prompt config |
| `bat` | Bat config |
| `kmonad` | Kmonad keyboard config |
| `karabiner` | Karabiner-Elements config |

## Adding new configs

```bash
# Create package structure
mkdir -p ~/dotfiles/newpkg/.config/newpkg

# Move config
mv ~/.config/newpkg/* ~/dotfiles/newpkg/.config/newpkg/

# Stow it
cd ~/dotfiles && stow newpkg
```

## Notes

- `~/.secrets` not tracked (contains API keys)
- `~/.gusto/` managed by Gusto's config_files repo

# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Bootstrap a New Mac

```bash
# 1. Install Homebrew (if needed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Clone and install
git clone git@github.com:kelvinscuesta/dotfiles.git ~/dotfiles
cd ~/dotfiles
brew bundle

# 3. Stow packages
# Work machine:
stow zsh zsh-work claude claude-work nvim git ghostty starship bat kmonad karabiner
# Personal machine (skip work config):
stow zsh claude nvim git ghostty starship bat kmonad karabiner

# 4. Post-stow setup
./bootstrap.sh
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
├── kmonad/        # Kmonad keyboard remapping (see kmonad/README.md)
├── karabiner/     # Karabiner-Elements
├── Brewfile       # Homebrew packages
└── bootstrap.sh   # Post-stow setup (bat themes, kmonad daemon, zim)
```

## Packages

| Package | Contents |
|---------|----------|
| `zsh` | `.zshrc`, `.zimrc`, `personal.zsh` |
| `zsh-work` | `work.zsh` (Gusto aliases, AWS, secrets) |
| `claude` | `CLAUDE.md`, statusline, skills, hooks |
| `claude-work` | `settings.json` (Bedrock, plugins), work skills |
| `nvim` | Neovim config (Lazy plugin manager, 20+ plugins) |
| `git` | `.gitconfig` (delta pager, GPG signing, aliases) |
| `ghostty` | Ghostty terminal + gruvbox-material themes |
| `starship` | Starship prompt config |
| `bat` | Bat config + Catppuccin themes |
| `kmonad` | Homerow mods config + LaunchDaemon plist |
| `karabiner` | Karabiner-Elements config |

## Adding new configs

```bash
mkdir -p ~/dotfiles/newpkg/.config/newpkg
mv ~/.config/newpkg/* ~/dotfiles/newpkg/.config/newpkg/
cd ~/dotfiles && stow newpkg
```

## Notes

- `~/.secrets` not tracked (contains API keys)
- `~/.gusto/` managed by Gusto's config_files repo
- kmonad requires extra setup — see `kmonad/README.md`

#!/usr/bin/env bash
set -euo pipefail

echo "=== Dotfiles post-stow bootstrap ==="

# Bat: build theme cache
if command -v bat &>/dev/null; then
  echo "[bat] Building theme cache..."
  bat cache --build
fi

# Zim: bootstrap zsh plugin manager
if [[ ! -d ~/.zim ]]; then
  echo "[zim] Installing Zim framework..."
  curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.sh | zsh
else
  echo "[zim] Already installed, updating modules..."
  zsh -c 'source ~/.zim/zimfw.zsh && zimfw install'
fi

# Kmonad: install LaunchDaemon
if [[ -f ~/dotfiles/kmonad/local.kmonad.plist ]]; then
  if [[ -f /Library/LaunchDaemons/local.kmonad.plist ]]; then
    echo "[kmonad] LaunchDaemon already installed, skipping"
  else
    echo "[kmonad] Installing LaunchDaemon..."
    echo "  You still need to:"
    echo "  1. Install Karabiner DriverKit VirtualHIDDevice (see kmonad/README.md)"
    echo "  2. Place kmonad binary at ~/kmonadbin"
    echo "  3. Run: sed \"s/YOUR_USERNAME/\$(whoami)/g\" ~/dotfiles/kmonad/local.kmonad.plist | sudo tee /Library/LaunchDaemons/local.kmonad.plist > /dev/null"
    echo "  4. Run: sudo launchctl bootstrap system/ /Library/LaunchDaemons/local.kmonad.plist"
    echo "  5. Grant Input Monitoring permission in System Settings"
  fi
fi

# Toggle theme shortcut: Cmd+Opt+Ctrl+T
if [[ -d ~/Library/Services/toggle\ light\ dark.workflow ]]; then
  echo "[macos] Setting Cmd+Opt+Ctrl+T shortcut for theme toggle..."
  defaults write pbs NSServicesStatus -dict-add \
    '"(null) - toggle light dark - runWorkflowAsService"' \
    '{ "key_equivalent" = "@~^t"; "presentation_modes" = { ContextMenu = 1; ServicesMenu = 1; TouchBar = 1; }; }'
fi

echo "=== Done ==="

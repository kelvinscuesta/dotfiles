#!/usr/bin/env bash
# Idempotent post-stow bootstrap — safe to re-run anytime
set -uo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
PASS=0
FAIL=0
SKIP=0

step() {
  echo ""
  echo "── $1 ──"
}

ok()   { echo "  ✓ $1"; ((PASS++)); }
skip() { echo "  · $1 (skipped)"; ((SKIP++)); }
fail() { echo "  ✗ $1"; ((FAIL++)); }

# ── Homebrew ─────────────────────────────────────────────────────
step "Homebrew"
if command -v brew &>/dev/null; then
  ok "brew found"
  if brew bundle check --file="$DOTFILES/Brewfile" &>/dev/null; then
    ok "all Brewfile packages installed"
  else
    echo "  Installing missing Brewfile packages..."
    if brew bundle --file="$DOTFILES/Brewfile"; then
      ok "Brewfile installed"
    else
      fail "brew bundle had errors (non-fatal, continuing)"
    fi
  fi
else
  fail "brew not found — install Homebrew first"
fi

# ── Stow verification ───────────────────────────────────────────
step "Stow symlinks"
missing_stow=()
for pkg in zsh claude codex nvim git ghostty starship bat tmux kanata macos; do
  if [[ -d "$DOTFILES/$pkg" ]]; then
    # Check if at least one file from the package is symlinked
    first_file=$(find "$DOTFILES/$pkg" -type f -not -name '.DS_Store' | head -1)
    if [[ -n "$first_file" ]]; then
      target="${first_file#$DOTFILES/$pkg/}"
      if [[ -L "$HOME/$target" ]]; then
        ok "$pkg stowed"
      else
        missing_stow+=("$pkg")
      fi
    fi
  fi
done
if [[ ${#missing_stow[@]} -gt 0 ]]; then
  for pkg in "${missing_stow[@]}"; do
    echo "  Stowing $pkg..."
    if (cd "$DOTFILES" && stow --adopt "$pkg" 2>/dev/null && git checkout -- "$pkg/" 2>/dev/null); then
      ok "$pkg stowed"
    elif (cd "$DOTFILES" && stow "$pkg" 2>/dev/null); then
      ok "$pkg stowed"
    else
      fail "$pkg — run 'stow --adopt $pkg' manually to resolve conflicts"
    fi
  done
fi

# ── Bat ──────────────────────────────────────────────────────────
step "Bat themes"
if command -v bat &>/dev/null; then
  bat cache --build &>/dev/null && ok "theme cache built" || fail "bat cache build"
else
  skip "bat not installed"
fi

# ── Zim ──────────────────────────────────────────────────────────
step "Zim (zsh plugin manager)"
if [[ -d ~/.zim ]]; then
  ok "already installed"
  zsh -ic 'zimfw install' &>/dev/null; ok "modules updated"
else
  echo "  Installing Zim..."
  curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.sh | zsh && ok "installed" || fail "zim install"
fi

# ── Neovim ───────────────────────────────────────────────────────
step "Neovim plugins"
if command -v nvim &>/dev/null; then
  nvim_version=$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+')
  if [[ "$(echo "$nvim_version >= 0.12" | bc 2>/dev/null)" == "1" ]]; then
    ok "nvim $nvim_version (0.12+ required)"
  else
    fail "nvim $nvim_version — need 0.12+ for native LSP"
  fi
  echo "  Syncing lazy.nvim plugins..."
  nvim --headless -c "Lazy sync" -c "qa!" &>/dev/null && ok "plugins synced" || fail "Lazy sync"
else
  skip "nvim not installed"
fi

# ── tmux TPM ─────────────────────────────────────────────────────
step "tmux plugin manager"
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [[ -d "$TPM_DIR" ]]; then
  ok "TPM already installed"
else
  echo "  Cloning TPM..."
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR" &>/dev/null && ok "TPM installed" || fail "TPM clone"
  echo "  Run prefix+I inside tmux to install plugins"
fi

# ── Lean toolchain ───────────────────────────────────────────────
step "Lean (elan)"
if command -v elan &>/dev/null; then
  if elan show 2>/dev/null | grep -q 'stable'; then
    ok "lean stable toolchain set"
  else
    elan default leanprover/lean4:stable &>/dev/null && ok "set lean4 stable" || fail "elan default"
  fi
else
  skip "elan not installed"
fi

# ── macOS theme shortcut ─────────────────────────────────────────
step "macOS theme toggle (Cmd+Opt+Ctrl+T)"
if [[ -d ~/Library/Services/toggle\ light\ dark.workflow ]]; then
  defaults write pbs NSServicesStatus -dict-add \
    '"(null) - toggle light dark - runWorkflowAsService"' \
    '{ "key_equivalent" = "@~^t"; "presentation_modes" = { ContextMenu = 1; ServicesMenu = 1; TouchBar = 1; }; }' \
    && ok "shortcut registered" || fail "defaults write"
else
  skip "workflow not stowed"
fi

# ── SSH key ──────────────────────────────────────────────────────
step "SSH key"
if [[ -f ~/.ssh/id_ed25519 ]]; then
  ok "ed25519 key exists"
else
  echo "  No SSH key found. Generate one:"
  echo "    ssh-keygen -t ed25519 -C \"$(git config user.email 2>/dev/null || echo 'your@email.com')\""
  skip "no SSH key"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "  ✓ $PASS passed  · $SKIP skipped  ✗ $FAIL failed"
echo "═══════════════════════════════════════"

[[ $FAIL -eq 0 ]]

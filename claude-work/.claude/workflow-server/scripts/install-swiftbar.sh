#!/usr/bin/env bash
# Install SwiftBar + link the workflow plugin.
# Idempotent: safe to re-run.

set -euo pipefail

PLUGIN_DIR="${HOME}/.claude/workflow-server/swiftbar"
PLUGIN_FILE="workflow.5s.sh"

# Install SwiftBar via brew if missing
if [[ ! -d /Applications/SwiftBar.app ]]; then
  echo "Installing SwiftBar via Homebrew..."
  brew install --cask swiftbar
else
  echo "SwiftBar already installed"
fi

# SwiftBar's plugin folder is configurable; default on first launch prompts user.
# We'll use a well-known path and set it.
SWIFTBAR_PLUGINS="${HOME}/Library/Application Support/SwiftBar/Plugins"
mkdir -p "${SWIFTBAR_PLUGINS}"

# Symlink our plugin in (so edits reflect live)
LINK="${SWIFTBAR_PLUGINS}/${PLUGIN_FILE}"
if [[ -L "${LINK}" ]]; then
  echo "Plugin symlink already present"
elif [[ -e "${LINK}" ]]; then
  echo "WARN: ${LINK} exists but is not a symlink — skipping"
else
  ln -s "${PLUGIN_DIR}/${PLUGIN_FILE}" "${LINK}"
  echo "Linked ${LINK} → ${PLUGIN_DIR}/${PLUGIN_FILE}"
fi

# Set SwiftBar plugin folder preference
defaults write com.ameba.SwiftBar PluginDirectory -string "${SWIFTBAR_PLUGINS}"

# Launch SwiftBar (noop if already running)
open -a SwiftBar

echo ""
echo "Done. Look for a dot in your menu bar."
echo "If missing, click SwiftBar in menu bar → Preferences → enable plugins."

#!/usr/bin/env bash
# Open Ghostty (or Terminal fallback) and tail workflow server logs.
# Sets window title via ANSI escape so you can tell windows apart.
set -euo pipefail

LOG_DIR="${HOME}/.claude/workflow-server/logs"
TITLE="🔧 Workflow · server logs"
# ANSI OSC 0 sets both icon & window title
TAIL_CMD=$'printf \'\\033]0;'"${TITLE}"$'\\007\'; echo "=== Tailing server stdout + stderr — Ctrl+C to exit ==="; echo "stdout: '"${LOG_DIR}/stdout.log"$'"; echo "stderr: '"${LOG_DIR}/stderr.log"$'"; echo; tail -F "'"${LOG_DIR}/stdout.log"$'" "'"${LOG_DIR}/stderr.log"$'"'

if [[ -d /Applications/Ghostty.app ]]; then
  /Applications/Ghostty.app/Contents/MacOS/ghostty -e bash -lc "${TAIL_CMD}" &
else
  osascript <<APPLESCRIPT
tell application "Terminal"
  activate
  do script "${TAIL_CMD}"
end tell
APPLESCRIPT
fi

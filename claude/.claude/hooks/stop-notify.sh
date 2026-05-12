#!/usr/bin/env bash
# Stop hook — desktop notification when Claude finishes a turn
# Respects WF_HEADLESS (skip for automated workflow runs)

set -euo pipefail

[[ "${WF_HEADLESS:-0}" == "1" ]] && exit 0

CWD=$(basename "$(pwd)")
TITLE="Claude Code"
MSG="Turn finished in $CWD"

if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier -title "$TITLE" -message "$MSG" -sound Tink -group claude-code 2>/dev/null
elif command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"Tink\"" 2>/dev/null
fi

# If workflow active, mirror to Slack via notify-slack.sh
if [[ -f ~/.claude/workflow/.env && -x ~/.claude/workflow/scripts/notify-slack.sh ]]; then
  if [[ -f ~/.claude/workflow/queue.json ]]; then
    ~/.claude/workflow/scripts/notify-slack.sh "session-end" "Claude turn done in $CWD" 2>/dev/null || true
  fi
fi

exit 0

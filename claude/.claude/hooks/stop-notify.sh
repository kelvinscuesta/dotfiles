#!/usr/bin/env bash
# Stop hook — desktop notification when Claude finishes a turn
# Respects WF_HEADLESS (skip for automated workflow runs)

set -euo pipefail

[[ "${WF_HEADLESS:-0}" == "1" ]] && exit 0

CWD=$(basename "$(pwd)")

# Add branch context if in a git repo
BRANCH=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null || true)
fi

# Build message with context
if [[ -n "$BRANCH" ]]; then
  TICKET=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)
  if [[ -n "$TICKET" ]]; then
    MSG="Done in $CWD ($TICKET)"
  else
    MSG="Done in $CWD [$BRANCH]"
  fi
else
  MSG="Done in $CWD"
fi

# Background agent context — prefix so you know which agent finished
if [[ -n "${CLAUDE_JOB_DIR:-}" ]]; then
  MSG="[bg] $MSG"
fi

TITLE="Claude Code"

# Prefer osascript — always at /usr/bin/osascript, no PATH issues inside tmux.
# terminal-notifier depends on mise PATH which tmux may not inherit.
/usr/bin/osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"Tink\"" 2>/dev/null || true

# Ghostty-native OSC 9 notification (shows with Ghostty icon in Notification Center)
if [[ -n "${TMUX:-}" ]]; then
  printf '\ePtmux;\e\e]9;%s\a\e\\' "$MSG"
else
  printf '\e]9;%s\a' "$MSG"
fi

# Terminal bell as fallback
printf '\a'

# If workflow active, mirror to Slack via notify-slack.sh
if [[ -f ~/.claude/workflow/.env && -x ~/.claude/workflow/scripts/notify-slack.sh ]]; then
  if [[ -f ~/.claude/workflow/queue.json ]]; then
    ~/.claude/workflow/scripts/notify-slack.sh "session-end" "Claude turn done in $CWD" 2>/dev/null || true
  fi
fi

exit 0

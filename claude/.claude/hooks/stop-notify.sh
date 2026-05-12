#!/usr/bin/env bash
# Stop hook — desktop notification when Claude finishes a turn
# Reads transcript for context: what Claude did, how long it took
# Primary: Ghostty OSC 9 (clickable). Fallback: osascript.

set -euo pipefail

[[ "${WF_HEADLESS:-0}" == "1" ]] && exit 0

# Read hook payload from stdin
PAYLOAD=$(cat)
TRANSCRIPT=$(echo "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null)

CWD=$(basename "$(pwd)")

# ── Branch / ticket context ──────────────────────────────────────
BRANCH=""
TICKET=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null || true)
  TICKET=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)
fi

# ── Extract what Claude did from transcript ──────────────────────
SUMMARY=""
DURATION=""
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  # Last assistant message with text content — what Claude said/did
  SUMMARY=$(tail -30 "$TRANSCRIPT" \
    | jq -r 'select(.type == "assistant") | [.message.content[]? | select(.type == "text") | .text] | join(" ")' 2>/dev/null \
    | sed '/^$/d' | tail -1 \
    | sed 's/\*\*//g; s/`//g; s/\n/ /g' \
    | cut -c1-120 \
    || true)

  # Duration: first timestamped entry → last
  FIRST_TS=$(jq -r 'select(.timestamp != null) | .timestamp' "$TRANSCRIPT" 2>/dev/null | head -1)
  LAST_TS=$(tail -10 "$TRANSCRIPT" | jq -r 'select(.timestamp != null) | .timestamp' 2>/dev/null | tail -1)
  if [[ -n "$FIRST_TS" && -n "$LAST_TS" ]]; then
    START=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${FIRST_TS%%.*}" "+%s" 2>/dev/null || true)
    END=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_TS%%.*}" "+%s" 2>/dev/null || true)
    if [[ -n "$START" && -n "$END" ]]; then
      ELAPSED=$((END - START))
      if (( ELAPSED >= 3600 )); then
        DURATION="$((ELAPSED / 3600))h$((ELAPSED % 3600 / 60))m"
      elif (( ELAPSED >= 60 )); then
        DURATION="$((ELAPSED / 60))m"
      else
        DURATION="${ELAPSED}s"
      fi
    fi
  fi
fi

# ── Build notification title + body ──────────────────────────────
TITLE="Claude Code"
[[ -n "$TICKET" ]] && TITLE="Claude · $TICKET"
[[ -n "$DURATION" ]] && TITLE="$TITLE ($DURATION)"

if [[ -n "$SUMMARY" ]]; then
  MSG="$SUMMARY"
else
  # Fallback when transcript unavailable
  if [[ -n "$TICKET" ]]; then
    MSG="Turn finished in $CWD ($TICKET)"
  elif [[ -n "$BRANCH" ]]; then
    MSG="Turn finished in $CWD [$BRANCH]"
  else
    MSG="Turn finished in $CWD"
  fi
fi

[[ -n "${CLAUDE_JOB_DIR:-}" ]] && TITLE="[bg] $TITLE"

# ── Ghostty OSC 9 — primary notification ─────────────────────────
# Clickable in Notification Center, shows Ghostty icon.
# Falls through silently when not in a terminal (background agents).
if [[ -n "${TMUX:-}" ]]; then
  printf '\ePtmux;\e\e]9;%s\a\e\\' "$MSG" 2>/dev/null || true
elif [[ -t 1 ]]; then
  printf '\e]9;%s\a' "$MSG" 2>/dev/null || true
fi

# ── osascript fallback — fires when OSC 9 can't reach Ghostty ────
# Background agents, detached sessions, non-Ghostty terminals.
if [[ -z "${TMUX:-}" && ! -t 1 ]] || [[ "${TERM_PROGRAM:-}" != "ghostty" && -z "${TMUX:-}" ]]; then
  /usr/bin/osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"Tink\"" 2>/dev/null || true
fi

# Terminal bell
printf '\a' 2>/dev/null || true

# ── Workflow Slack mirror ─────────────────────────────────────────
if [[ -f ~/.claude/workflow/.env && -x ~/.claude/workflow/scripts/notify-slack.sh ]]; then
  if [[ -f ~/.claude/workflow/queue.json ]]; then
    ~/.claude/workflow/scripts/notify-slack.sh "session-end" "$MSG" 2>/dev/null || true
  fi
fi

exit 0

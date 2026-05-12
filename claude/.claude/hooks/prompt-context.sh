#!/usr/bin/env bash
# UserPromptSubmit hook — inject git branch, ticket ID, workflow queue snippet
# Only runs when inside a git repo. Silent otherwise.

set -euo pipefail

# Skip for headless workflow sessions (preamble covers it)
[[ "${WF_HEADLESS:-0}" == "1" ]] && exit 0

# Only inject if in git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

BRANCH=$(git branch --show-current 2>/dev/null || echo "")
[[ -z "$BRANCH" ]] && exit 0

# Extract ticket ID from branch name (kelvin/PAY-12345-slug → PAY-12345)
TICKET=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)

OUT="## Session context"
OUT="$OUT
- branch: $BRANCH"
[[ -n "$TICKET" ]] && OUT="$OUT
- ticket: $TICKET"

# Append workflow queue snippet if ticket matches an active queue entry
if [[ -n "$TICKET" && -f ~/.claude/workflow/queue.json ]]; then
  STATUS=$(jq -r --arg t "$TICKET" '.tickets[]? | select(.id==$t) | .status' ~/.claude/workflow/queue.json 2>/dev/null || true)
  [[ -n "$STATUS" && "$STATUS" != "null" ]] && OUT="$OUT
- workflow status: $STATUS"
fi

echo "$OUT"
exit 0

#!/bin/bash
# SessionStart hook: emit reminder if pending follow-up plans exist
shopt -s nullglob
files=(~/.claude/plans/*-follow-up.md)
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
  exit 0
fi

# Check if any file has unchecked items
has_pending=false
for f in "${files[@]}"; do
  if grep -q '^\- \[ \]' "$f"; then
    has_pending=true
    break
  fi
done

if [ "$has_pending" = true ]; then
  echo "<user-prompt-submit-hook>Pending follow-up plans found. Run /follow-up-reminder to check.</user-prompt-submit-hook>"
fi

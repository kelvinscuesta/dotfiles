#!/bin/bash
# SessionEnd hook: check current branch's PR for unresolved comments/nits
# and write them to a follow-up plan if any exist

# Read JSON input from stdin (Claude Code passes hook context via stdin)
INPUT=$(cat)

# Need to be in a git repo
cd "$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)" 2>/dev/null || exit 0

# Get current branch
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$branch" ] && exit 0

# Try to find an open PR for this branch
pr_json=$(gh pr view "$branch" --json number,title,url,state 2>/dev/null)
[ -z "$pr_json" ] && exit 0

pr_state=$(echo "$pr_json" | jq -r '.state')
[ "$pr_state" != "OPEN" ] && exit 0

pr_number=$(echo "$pr_json" | jq -r '.number')
pr_title=$(echo "$pr_json" | jq -r '.title')
pr_url=$(echo "$pr_json" | jq -r '.url')
repo=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)

# Extract ticket ID from branch name (e.g., kelvin/PAY-37592-foo -> PAY-37592)
ticket_id=$(echo "$branch" | grep -oE '[A-Z]+-[0-9]+' | head -1)
[ -z "$ticket_id" ] && ticket_id="NO-TICKET"

follow_up_file="$HOME/.claude/plans/${ticket_id}-follow-up.md"

# Get review comments
comments=$(gh api "repos/${repo}/pulls/${pr_number}/comments" 2>/dev/null)
[ -z "$comments" ] || [ "$comments" = "[]" ] && exit 0

# Build list of files that exist in the current branch (skip deleted file comments)
existing_files=$(git ls-files 2>/dev/null)

# Track seen path:line combos to deduplicate comment threads
declare -A seen_locations

items=""
while IFS= read -r line; do
  author=$(echo "$line" | jq -r '.user.login')
  body=$(echo "$line" | jq -r '.body')
  path=$(echo "$line" | jq -r '.path')
  line_num=$(echo "$line" | jq -r '.line // .original_line // "?"')

  # Skip comments on files that no longer exist in the branch
  if ! echo "$existing_files" | grep -qF "$path"; then
    continue
  fi

  # Skip duplicate path:line (only keep first comment in a thread)
  loc_key="${path}:${line_num}"
  if [ -n "${seen_locations[$loc_key]+x}" ]; then
    continue
  fi
  seen_locations[$loc_key]=1

  # Match actionable follow-up patterns — must start the comment or be the clear intent
  # Patterns: "nit:", "follow up", "future pr", "will be", "addressed in", "todo",
  #           "consider", "could we", "might want", "optional"
  # Exclude conversational replies: require pattern near start of comment (first 200 chars)
  first_chunk=$(echo "$body" | head -3 | cut -c1-200)
  if echo "$first_chunk" | grep -qiE '(^nit:|follow.?up|todo|future pr|in a future|will be .*(future|follow|later|next)|addressed in|should we|could we|might want to|optional:)'; then
    # Truncate body to first line, max 120 chars
    summary=$(echo "$body" | head -1 | cut -c1-120)
    items="${items}- [ ] **${path}:${line_num}** — ${summary} (${author})\n"
  fi
done < <(echo "$comments" | jq -c '.[]')

# Nothing actionable found
[ -z "$items" ] && exit 0

# Check if follow-up file already exists
if [ -f "$follow_up_file" ]; then
  # Append new items if they aren't already in the file
  new_items=""
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    # Check if this item (by path:line) is already tracked
    check_str=$(echo "$item" | grep -oE '\*\*[^*]+\*\*' | head -1)
    if ! grep -qF "$check_str" "$follow_up_file" 2>/dev/null; then
      new_items="${new_items}${item}\n"
    fi
  done < <(echo -e "$items")

  if [ -n "$new_items" ]; then
    echo "" >> "$follow_up_file"
    echo "## New comments ($(date +%Y-%m-%d))" >> "$follow_up_file"
    echo "" >> "$follow_up_file"
    echo -e "$new_items" >> "$follow_up_file"
  fi
else
  # Create new follow-up file
  mkdir -p "$(dirname "$follow_up_file")"
  cat > "$follow_up_file" << EOF
# ${ticket_id} — Follow-up items from PR #${pr_number}

> ${pr_title}
> ${pr_url}

## Follow-up PR items

$(echo -e "$items")
EOF
fi

exit 0

---
name: wf-ack-pr
description: Acknowledge PR comments — marks all new comments on a PR as seen. Use after posting your replies. Use when user says "/wf-ack-pr <pr-number>", "ack PR comments", "mark PR feedback handled".
argument-hint: "<repo> <pr-number>"
---

# wf-ack-pr

Mark drafts as reviewed / comments as seen. Updates `last_seen_comment_id` so the next poll doesn't re-process.

## Inputs

- `$1` = repo (e.g., `Gusto/zenpayroll`)
- `$2` = PR number

## Procedure

### 1. Find the highest comment ID across all comment sources

```bash
REVIEW_MAX=$(gh api "repos/${REPO}/pulls/${NUM}/comments" --jq '[.[].id] | max // 0')
ISSUE_MAX=$(gh api "repos/${REPO}/issues/${NUM}/comments" --jq '[.[].id] | max // 0')
REVIEWS_MAX=$(gh api "repos/${REPO}/pulls/${NUM}/reviews" --jq '[.[].id] | max // 0')
MAX_ID=$(echo "$REVIEW_MAX $ISSUE_MAX $REVIEWS_MAX" | tr ' ' '\n' | sort -rn | head -1)
```

### 2. Update queue.json

```bash
jq --arg repo "$REPO" --argjson num "$NUM" --argjson id "$MAX_ID" '
  .prs |= map(
    if .repo == $repo and .number == $num then
      .last_seen_comment_id = $id | .pending_comments = 0 | .draft_path = null
    else . end
  )
'
```

### 3. Optionally archive drafts

Ask user: "Archive drafts folder `drafts/pr-${NUM}/`?" (yes/no)
If yes: move to `drafts/archived/pr-${NUM}-YYYY-MM-DD/`

### 4. Audit + dashboard

```bash
audit.sh "ACK" "PR #${NUM} comments acknowledged (last_seen_id=${MAX_ID})"
update-dashboard.sh > /dev/null
```

### 5. Output

```
✅ PR #<number> comments acknowledged
No more pending comments — card removed from PR Feedback column
```

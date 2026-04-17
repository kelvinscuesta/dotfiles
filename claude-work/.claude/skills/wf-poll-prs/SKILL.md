---
name: wf-poll-prs
description: Internal workflow skill. Invoked by cron every 15min. Polls GitHub PRs for merged/closed status and new comments. Triggers PR analysis on new comments, cleanup on merged.
---

# wf-poll-prs

Cron-invoked PR polling cycle.

## Procedure

### 1. Check workflow state

```bash
STATE=$(jq -r '.workflow_state' ~/.claude/workflow/queue.json)
```

If `paused` or `stopped`, exit silently.

### 2. Run poll script

```bash
RESULTS=$(~/.claude/workflow/scripts/poll-prs.sh 2>/dev/null)
OPEN_PRS=$(echo "$RESULTS" | jq '.open_prs')
CLOSED_PRS=$(echo "$RESULTS" | jq '.closed_prs')
NEW_COMMENTS=$(echo "$RESULTS" | jq '.new_comments')
```

### 3. Handle closed PRs (cleanup worktrees)

For each PR in `$CLOSED_PRS`:
- Look up associated ticket by `.pr_number` + `.pr_repo`
- If `.merged == true`:
  - Remove worktree at `.worktree_path`: `git worktree remove <path>`
  - Delete local branch: `git branch -D <branch>`
  - Move ticket from `.tickets` to `.completed` with `type: "ticket"`, `completed_at: <now>`, `pr_number`, `repo`
- If closed without merge:
  - Set ticket status back to `awaiting-approval` (or `rejected`)
  - Leave worktree for debugging
- Remove PR from `.prs`
- Audit: `CLEANUP "<ticket-id> merged → worktree removed"` or `CLEANUP "<ticket-id> PR closed without merge"`
- Slack notify (merged): 🎉 *<ticket-id>* merged — worktree cleaned

### 4. Update PR tracking

For each PR in `$OPEN_PRS`:
- Upsert in `.prs` (update title, updatedAt, is_draft)

### 5. Process new comments

Group `$NEW_COMMENTS` by `(repo, pr_number)`. For each PR with new comments:
- Update `.prs[i].pending_comments = <count>`
- Invoke `Skill` tool with `skill: wf-analyze-pr`, args: `<repo> <pr-number>`

### 6. Prune completed items older than 7 days

```bash
jq '.completed |= map(select((.completed_at | fromdateiso8601) > (now - 7*86400)))'
```

### 7. Regenerate dashboard

```bash
~/.claude/workflow/scripts/update-dashboard.sh > /dev/null
```

## Never

- Never auto-post comments
- Never push code to remote branches
- Never skip cleanup for merged PRs (worktrees accumulate disk cruft)

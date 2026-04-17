---
name: wf-feed
description: Manually add a Jira ticket to the workflow queue for classification. Skips the poll, goes straight to classify. Use when user says "/wf-feed <ticket-id>", "feed ticket X", "add TICKET-123 to workflow", or "process this ticket".
argument-hint: "<ticket-id>"
---

# wf-feed

Manually queue a ticket for classification.

## Inputs

- `$1` = Jira ticket ID (e.g., `PAY-38012`)

## Procedure

### 1. Validate ticket exists in Jira

```bash
acli jira workitem view "$TICKET_ID" --json
```

If not found, abort with error.

### 2. Check if already in queue

```bash
EXISTS=$(jq -r --arg id "$TICKET_ID" '[.tickets[], .backlog[], .completed[]] | map(select(.id == $id)) | length' "$QUEUE_FILE")
```

If already present:
- In `.tickets` — ask: re-classify? (yes/no)
- In `.backlog` — promote to active, then classify
- In `.completed` — ask: reopen? (yes/no)

### 3. Fetch ticket data and add to queue

Use MCP `mcp__claude_ai_Jira_Confluence__getJiraIssue` for richer data (description, attachments, comments).

Append to `.tickets[]` with:
- `.status = "new"`
- `.added_at = (now | todate)`
- `.added_via = "manual"`

### 4. Audit

```bash
audit.sh "FEED" "$TICKET_ID added via manual feed"
```

### 5. Invoke classifier

Use `Skill` tool with `skill: wf-classify`, argument: `$TICKET_ID`.

### 6. Regenerate dashboard

### 7. Output

Defer to classifier's output.

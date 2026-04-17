---
name: wf-approve
description: Approve a classified Jira ticket for implementation. Writes a pending marker that the workflow server (or /wf-next) will pick up to run TDD implementation + draft PR. Use when user says "/wf-approve <ticket-id>", "approve ticket X", or "greenlight TICKET-123 for implementation".
argument-hint: "<ticket-id>"
---

# wf-approve

Approve a ticket for implementation by queuing a pending marker.

## Inputs

- `$1` = ticket ID (e.g., `PAY-38012`)

## Procedure

### 1. Validate

```bash
QUEUE_FILE="$HOME/.claude/workflow/queue.json"
TICKET_ID="$1"
STATUS=$(jq -r --arg id "$TICKET_ID" '.tickets[] | select(.id == $id) | .status' "$QUEUE_FILE")
PLAN_PATH=$(jq -r --arg id "$TICKET_ID" '.tickets[] | select(.id == $id) | .plan_path // ""' "$QUEUE_FILE")
```

If `$STATUS != "awaiting-approval"`, abort — only `awaiting-approval` tickets can be approved.
If no plan exists, abort and suggest `/wf-feed` to re-classify.

### 2. Update queue status

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg id "$TICKET_ID" --arg now "$NOW" \
  '.tickets |= map(if .id == $id then .status = "in-progress" | .approved_at = $now else . end)' \
  "$QUEUE_FILE" > /tmp/q.json && mv /tmp/q.json "$QUEUE_FILE"
```

### 3. Write implement marker

```bash
PENDING_DIR="$HOME/.claude/workflow/pending/implement"
mkdir -p "$PENDING_DIR"
cat > "$PENDING_DIR/$TICKET_ID.json" <<EOF
{
  "kind": "implement",
  "ticket_id": "$TICKET_ID",
  "plan_path": "$PLAN_PATH",
  "approved_at": "$NOW",
  "created_at": "$NOW"
}
EOF
```

### 4. Audit

```bash
~/.claude/workflow/scripts/audit.sh "APPROVE" "$TICKET_ID approved — implement marker written"
```

### 5. Regenerate dashboard

```bash
~/.claude/workflow/scripts/update-dashboard.sh > /dev/null
```

### 6. Notify user based on server status

Check if server is running:
```bash
SERVER_RUNNING=$(~/.claude/workflow-server/scripts/server-status.sh | jq -r '.running')
```

- If `true`: server will pick up marker automatically → report "Approved, server will begin implementation shortly"
- If `false`: tell user to run `/wf-next` manually or start the server

### 7. Report

```
✅ $TICKET_ID approved — implement marker queued
Server running: <yes/no>
  (if yes) → server will drain shortly
  (if no)  → run /wf-next or start server in SwiftBar menu
```

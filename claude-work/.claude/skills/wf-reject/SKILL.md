---
name: wf-reject
description: Remove a ticket from the active queue (not going to work on it). Logs reason, moves to rejected state. Use when user says "/wf-reject <ticket-id>", "reject ticket X", "skip TICKET-123".
argument-hint: "<ticket-id> [reason]"
---

# wf-reject

Remove a ticket from queue.

## Inputs

- `$1` = ticket ID
- `$2` = optional reason

## Procedure

### 1. Ask for reason (if not provided)

If `$2` empty, ask user: "Reason for rejecting $TICKET_ID? (optional, press Enter to skip)"

### 2. Remove from tickets, optionally backup to completed

```bash
jq --arg id "$TICKET_ID" --arg reason "$REASON" '
  .completed += [{
    id: $id,
    type: "ticket",
    title: (.tickets[] | select(.id == $id)).title,
    completed_at: (now | todate),
    disposition: "rejected",
    reason: $reason
  }] | .tickets |= map(select(.id != $id))
'
```

### 3. Audit

```bash
audit.sh "REJECT" "$TICKET_ID rejected: $REASON"
```

### 4. Regenerate dashboard

### 5. Output

```
❌ $TICKET_ID removed from queue
Reason: $REASON
```

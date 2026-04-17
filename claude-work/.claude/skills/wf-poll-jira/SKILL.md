---
name: wf-poll-jira
description: Internal workflow skill. Invoked by cron every hour. Polls Jira for new tickets, updates queue, triggers classification on new active tickets.
---

# wf-poll-jira

Cron-invoked Jira polling cycle.

## Procedure

### 1. Check workflow state

```bash
STATE=$(jq -r '.workflow_state' ~/.claude/workflow/queue.json)
```

If state is `paused` or `stopped`, log and exit silently.

### 2. Run poll script

```bash
RESULTS=$(~/.claude/workflow/scripts/poll-jira.sh 2>/dev/null)
ACTIVE=$(echo "$RESULTS" | jq '.active')
BACKLOG=$(echo "$RESULTS" | jq '.backlog')
```

### 3. Merge new tickets into queue

For each ticket in `$ACTIVE`:
- Append to `.tickets` with `.status = "new"`, `.added_at = <now>`, `.added_via = "poll"`

For each ticket in `$BACKLOG`:
- Append to `.backlog` with `.status = "backlog"`, `.added_at = <now>`

Update `.last_updated = <now>` in queue.json.

### 4. Classify each new active ticket

For each newly added active ticket, invoke `Skill` tool with `skill: wf-classify`, argument: ticket ID.

Do NOT classify backlog items — those go into digest.

### 5. Backlog digest (once per day at first poll)

If first poll of the day AND `.backlog` has items not previously digested:
- Send Slack notification via MCP with backlog summary (IDs, titles, count)
- Mark digested via `.digested_at` field per backlog item

### 6. Regenerate dashboard

```bash
~/.claude/workflow/scripts/update-dashboard.sh > /dev/null
```

## Never

- Never classify backlog items automatically
- Never call this skill outside of cron context (use `/wf-feed` for manual)
- Never fail silently without audit log entry

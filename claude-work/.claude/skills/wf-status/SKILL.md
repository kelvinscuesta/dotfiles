---
name: wf-status
description: Show workflow dashboard summary in terminal. Use when user says "/wf-status", "what's in the queue", "workflow status", "show workflow dashboard".
---

# wf-status

Print a compact terminal summary of workflow state.

## Procedure

### 1. Read queue

```bash
QUEUE=$(cat ~/.claude/workflow/queue.json)
STATE=$(echo "$QUEUE" | jq -r '.workflow_state')
```

### 2. Print formatted summary

```
🔧 Dev Workflow — <STATE>
Last updated: <timestamp>

QUEUE (<N>)
  PAY-38012  Fix payroll rounding          [NEW]
  PAY-38015  Add tooltip                   [NEW]

AWAITING APPROVAL (<N>)
  PAY-37999  Migrate auth middleware       [READY]

IN PROGRESS (<N>)
  PAY-37980  Update step nav               [CODING]

PR FEEDBACK (<N>)
  #11298  3 new comments

BACKLOG (<N>)  (run /wf-status --backlog to see)

COMPLETED TODAY (<N>)

Dashboard: file://<path>
```

### 3. Optional flags

- `--backlog` — expand backlog list
- `--json` — raw JSON for scripting
- `--verbose` — include recent audit entries

## Output

Print directly. No Slack notification, no state change.

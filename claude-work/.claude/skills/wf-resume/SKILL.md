---
name: wf-resume
description: Resume paused workflow. Use when user says "/wf-resume", "resume workflow", "unpause", "continue automation".
---

# wf-resume

Resume from paused state.

## Procedure

### 1. Verify currently paused

```bash
STATE=$(jq -r '.workflow_state' ~/.claude/workflow/queue.json)
```

If not `paused`, report current state and exit.

### 2. Set state to running

```bash
jq '.workflow_state = "running"' queue.json
```

### 3. Run immediate poll

```bash
~/.claude/workflow/scripts/poll-jira.sh
~/.claude/workflow/scripts/poll-prs.sh
```

### 4. Audit + regen dashboard

```bash
audit.sh "RESUME" "workflow resumed"
~/.claude/workflow/scripts/update-dashboard.sh > /dev/null
```

### 5. Output

```
▶  Workflow resumed — polling active
```

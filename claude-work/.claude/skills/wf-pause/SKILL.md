---
name: wf-pause
description: Pause the workflow temporarily (crons don't fire, but state preserved). Use when user says "/wf-pause", "pause workflow", "hold on the automation", "stop polling for a bit".
---

# wf-pause

Pause active polling without tearing down state.

## Procedure

### 1. Set workflow state

```bash
jq '.workflow_state = "paused"' queue.json
```

### 2. Audit

```bash
audit.sh "PAUSE" "workflow paused"
```

### 3. Regenerate dashboard

Dashboard shows PAUSED state badge.

### 4. Output

```
⏸  Workflow paused — crons will not fire until /wf-resume
```

Note: Cron jobs stay scheduled. Each cron invocation checks `workflow_state` and exits silently if paused. This way we don't have to re-setup crons on resume.

---
name: wf-stop
description: Stop the automated dev workflow. Tears down cron jobs, sends daily summary to Slack, rotates audit log. Use when user says "stop workflow", "end dev automation", "/wf-stop", or wants to shut down automation at end of workday.
---

# wf-stop

Stop the workflow for the day.

## Procedure

### 1. Tear down cron jobs

Use `CronDelete` tool to remove the two jobs created by `/wf-start`:
- Jira poll job
- PR poll job

List via `CronList` first, delete by ID.

### 2. Generate daily summary

From today's `audit.log`:

```bash
TICKETS_CLASSIFIED=$(grep -c "\[CLASSIFY\]" ~/.claude/workflow/audit.log)
TICKETS_READY=$(grep "\[CLASSIFY\].*→ ready" ~/.claude/workflow/audit.log | wc -l)
TICKETS_IMPLEMENTED=$(grep "\[IMPLEMENT\].*PR #" ~/.claude/workflow/audit.log | wc -l)
PR_COMMENTS_HANDLED=$(grep "\[DRAFT\].*PR #" ~/.claude/workflow/audit.log | wc -l)
PRS_MERGED=$(grep "\[CLEANUP\].*merged" ~/.claude/workflow/audit.log | wc -l)
```

### 3. Send summary to Slack

Via MCP `mcp__claude_ai_Slack_Gusto_Offical__slack_send_message` (record-keeping only):

```
🔴 *Dev Workflow Stopped — Daily Summary*

📊 *Today*
• Tickets classified: <N> (<N> ready, <M> needs-clarification)
• Tickets implemented: <N>
• PRs merged: <N>
• PR comments drafted: <N>

⏭️ *Remaining*
• Awaiting approval: <N>
• In progress: <N>
• PR feedback pending: <N>

Dashboard snapshot: file://<path>
```

### 4. Set workflow state

```bash
jq '.workflow_state = "stopped"' queue.json
```

### 5. Rotate audit log

```bash
TODAY=$(date +%Y-%m-%d)
mv ~/.claude/workflow/audit.log ~/.claude/workflow/audit-history/audit-${TODAY}.log
touch ~/.claude/workflow/audit.log
```

### 6. Regenerate dashboard (shows stopped state)

```bash
~/.claude/workflow/scripts/update-dashboard.sh > /dev/null
```

### 7. Audit

New log entry: `audit.sh "STOP" "workflow stopped"`

## Output

```
🔴 Workflow stopped
Summary posted to Slack
Audit rotated: audit-<date>.log
Dashboard shows STOPPED state
```

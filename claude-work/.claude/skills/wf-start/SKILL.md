---
name: wf-start
description: Start the automated dev workflow. Sets up cron jobs to poll Jira hourly and GitHub PRs every 15min, initializes queue state, opens dashboard, notifies Slack. Use when user says "start workflow", "begin dev automation", "/wf-start", or wants to boot up the automation for the workday.
---

# wf-start

Boot the automated dev workflow for the day.

## Procedure

### 1. Check preconditions

```bash
WORKFLOW_DIR="$HOME/.claude/workflow"
QUEUE_FILE="$WORKFLOW_DIR/queue.json"

# Load env
source "$WORKFLOW_DIR/.env"
```

Verify:
- `$SLACK_CHANNEL_ID` is set
- `acli` authenticated (`acli jira auth status`)
- `gh` authenticated (`gh auth status`)

If any fail, abort with clear error.

### 2. Reset workflow state

```bash
jq '.workflow_state = "running" | .last_updated = (now | todate)' "$QUEUE_FILE" > /tmp/queue.json && mv /tmp/queue.json "$QUEUE_FILE"
```

### 3. Initial poll (catches anything new since last session)

```bash
~/.claude/workflow/scripts/poll-jira.sh --verbose
~/.claude/workflow/scripts/poll-prs.sh --verbose
```

Integrate results into queue (new tickets → tickets[], new PRs → prs[], existing PR comment counts → update pending_comments).

### 4. Set up cron schedules

Use `CronCreate` tool (NOT external cron). Two recurring jobs:

**Job A: Jira poll (hourly, work hours only)**
```
schedule: "0 9-18 * * 1-5"   # every hour, 9am-6pm Mon-Fri
command: /wf-poll-jira
```

**Job B: PR poll (every 15min, work hours only)**
```
schedule: "*/15 9-18 * * 1-5"  # every 15min, 9am-6pm Mon-Fri
command: /wf-poll-prs
```

Note: Internal poll skills `wf-poll-jira` and `wf-poll-prs` chain plumbing scripts → classify/analyze skills per new item.

### 5. Regenerate dashboard

```bash
~/.claude/workflow/scripts/update-dashboard.sh > /dev/null
```

### 6. Open dashboard in browser

```bash
open "file://$WORKFLOW_DIR/status.html"
```

### 7. Notify Slack

Use MCP `mcp__claude_ai_Slack_Gusto_Offical__slack_send_message` (record-keeping only):

```
🟢 *Dev Workflow Started*

Active sprint tickets: <N>
Backlog tickets: <N>
Open PRs: <N>
Pending PR comments: <N>

Polls: Jira hourly, PRs every 15min (9am-6pm)
Dashboard: file://<path>
```

Channel: `$SLACK_CHANNEL_ID`

### 8. Audit

```bash
~/.claude/workflow/scripts/audit.sh "START" "workflow started — active: $N tickets, $M PRs"
```

### 9. Classify any NEW active tickets immediately

For each ticket in `.tickets[]` with `.status == "new"`:
- Invoke `Skill` tool with `skill: wf-classify`, passing ticket ID

Don't classify backlog on startup — those get periodic digest only.

### 10. Analyze any PRs with new comments

For each PR in `.prs[]` with `.pending_comments > 0`:
- Invoke `Skill` tool with `skill: wf-analyze-pr`, passing repo + number

## Output

```
🟢 Workflow running
Active: <N> tickets, <M> PRs
Dashboard opened in browser
Crons scheduled: Jira hourly, PR every 15min
```

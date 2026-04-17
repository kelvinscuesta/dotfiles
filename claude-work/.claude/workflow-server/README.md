# Workflow Server

Long-running local server that automates ticket classification, PR comment analysis, and CI monitoring. Controlled via SwiftBar menu bar. Hands off AI work to Claude Code via pending markers.

## Architecture

```
┌────────────── SwiftBar menu bar ──────────────┐
│  ● Workflow  →  [Start] [Stop] [Dashboard]    │
└───────────────────┬───────────────────────────┘
                    │
┌───────────────────▼───────────────────────────┐
│  Workflow Server (Bun + TS, port 3000)        │
│                                               │
│  Timers:      Jira 1h, PRs 15min (work hrs)   │
│  Dashboard:   http://localhost:3000           │
│  Status API:  http://localhost:3000/status.json│
│  State:       ~/.claude/workflow/queue.json   │
│  Audit:       ~/.claude/workflow/audit.log    │
│                                               │
│  On new work:                                 │
│    poll-jira → writes pending/classify/*.json │
│    poll-prs  → writes pending/analyze-pr/*.json│
│    wf-approve→ writes pending/implement/*.json│
│                                               │
│  Runner drains pending via:                   │
│    claude -p "/wf-classify PAY-X" (headless)  │
└───────────────────┬───────────────────────────┘
                    │ markers in ~/.claude/workflow/pending/
                    ▼
┌──────────── Claude Code (headless) ───────────┐
│  Consumes markers, runs AI skills:            │
│    wf-classify  → writes plans/<ticket>.md    │
│    wf-implement → creates worktree + draft PR │
│    wf-analyze-pr → writes drafts/pr-*/        │
└───────────────────────────────────────────────┘
```

## Lifecycle

| Action | How |
|--------|-----|
| Start | Menu bar ▶ Start (or `scripts/server-start.sh`) |
| Stop | Menu bar ◼ Stop (or `scripts/server-stop.sh`) |
| Restart | Menu bar ↻ Restart |
| Status | Menu bar, or `scripts/server-status.sh` |
| Logs | Menu bar View Logs, or `tail -f logs/stdout.log` |

Logs are at:
- `~/.claude/workflow-server/logs/stdout.log`
- `~/.claude/workflow-server/logs/stderr.log`
- `~/.claude/workflow-server/logs/<classify|implement|analyze>-*.log` (per headless run)

## User flow (after server running)

1. **Morning:** click SwiftBar ▶ Start. Open dashboard at `http://localhost:3000`.
2. **Jira poll fires** → new ticket classified automatically → plan written.
3. **You review plan** → `/wf-approve PAY-X` in Claude Code → marker queued → server implements → draft PR created.
4. **PR comments arrive** → server auto-analyzes → drafts in `~/.claude/workflow/drafts/pr-<N>/`.
5. **End of day:** click SwiftBar ◼ Stop.

## Commands

| Command | Purpose |
|---------|---------|
| `/wf-feed PAY-X` | Manually queue a ticket for classification |
| `/wf-approve PAY-X` | Approve for implementation (writes marker) |
| `/wf-reject PAY-X` | Remove from queue |
| `/wf-status` | Show dashboard summary in terminal |
| `/wf-next` | Drain pending markers manually (if server off) |
| `/wf-ack-pr <repo> <num>` | Mark PR comments as seen |
| `/wf-pause`, `/wf-resume` | Pause/resume workflow state |

## Environment

`~/.claude/workflow/.env` holds config:
- `SLACK_CHANNEL_ID` / `SLACK_USER_ID` — Slack audit log destination
- `JIRA_USER`, `JIRA_PROJECT`

Server environment vars (optional):
- `JIRA_INTERVAL_MS` — override default 1h
- `PR_INTERVAL_MS` — override default 15min
- `IGNORE_WORK_HOURS=1` — poll 24/7 instead of 9am-6pm M-F
- `AUTO_DRAIN=0` — disable auto-drain (markers written but not consumed)
- `DASHBOARD_PORT=3000`
- `CLAUDE_BIN` — override path to `claude` CLI
- `BUN_BIN` — override path to `bun`

## Tests

```bash
cd ~/.claude/workflow-server
bun test
```

22 tests across 7 files covering state, audit, sh, pending, runner, dashboard, and real Jira/GH integration.

## Pending: Slack Bot (Phase 3)

Socket Mode bot for interactive approve/reject from Slack. Requires Gusto admin approval for Slack app installation. Waiting on approval.

When ready, will add:
- `src/slack.ts` — Socket Mode client, event handlers
- Interactive buttons on classification notifications
- Slash commands: `/wf-approve`, `/wf-reject`, etc. from Slack
- Real notifications (bot identity bypasses Slack's self-message suppression)

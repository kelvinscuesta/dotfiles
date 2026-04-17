---
name: wf-next
description: Drain the pending work queue. Reads ~/.claude/workflow/pending/ markers and runs the appropriate skill (wf-classify, wf-implement, wf-analyze-pr) for each. Use when user says "/wf-next", "run next workflow task", "drain pending", "work through the queue", "what's next in the workflow".
---

# wf-next

Manually drain the workflow pending queue. Complements the server (which auto-drains) — use when server is off or you want to process interactively.

## Inputs

None. Optional:
- `--kind <classify|implement|analyze-pr>` — filter to one type
- `--limit N` — process at most N markers

## Procedure

### 1. List pending markers

```bash
CLASSIFY_DIR=~/.claude/workflow/pending/classify
IMPLEMENT_DIR=~/.claude/workflow/pending/implement
ANALYZE_DIR=~/.claude/workflow/pending/analyze-pr

ls "$CLASSIFY_DIR"/*.json 2>/dev/null
ls "$IMPLEMENT_DIR"/*.json 2>/dev/null
ls "$ANALYZE_DIR"/*.json 2>/dev/null
```

Collect all marker file paths. Sort by mtime (oldest first = FIFO).

### 2. If empty, exit

```
✅ No pending work.
Queue: <tickets> tickets / <prs> PRs / <backlog> backlog
```

### 3. For each marker, in FIFO order:

Read marker JSON. Based on `.kind`:

- **classify**: Invoke `Skill` tool with `skill: wf-classify`, argument: `.ticket_id`
- **implement**: Invoke `Skill` tool with `skill: wf-implement`, argument: `.ticket_id`
- **analyze-pr**: Invoke `Skill` tool with `skill: wf-analyze-pr`, arguments: `.repo .pr_number`

After the invoked skill returns successfully, delete the marker file:

```bash
rm "$MARKER_PATH"
```

If the skill fails, leave the marker in place for retry. Log error, stop processing (don't cascade failures).

### 4. Report

Brief summary:

```
Drained 3 markers:
- PAY-38012 classified → ready
- PAY-37999 classified → needs-clarification
- PR #11298 analyzed (3 comments)

Remaining pending: 0
```

## Interaction with server

- **Server running**: you and the server race to consume markers. Safe — file deletes are atomic. Whoever wins removes the marker.
- **Server down**: this skill is the only way to process pending work.

Check server status:
```bash
~/.claude/workflow-server/scripts/server-status.sh | jq '.running'
```

## Never

- Never skip marker deletion after a successful skill run
- Never cascade failures — stop on first error, let user intervene

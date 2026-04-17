---
name: wf-classify
description: Internal workflow skill. Classify a Jira ticket as ready-for-dev or needs-clarification. Writes plan (ready) or clarification draft (not ready). Updates queue.json and dashboard. Invoked by /wf-feed and Jira polling cron.
argument-hint: "<ticket-id>"
---

# wf-classify

Classify a single Jira ticket to determine if it has enough information to implement. Output plan or clarification draft.

## Inputs

- `$1` = ticket ID (e.g., `PAY-38012`)

## Procedure

### 1. Load context

```bash
WORKFLOW_DIR="$HOME/.claude/workflow"
QUEUE_FILE="$WORKFLOW_DIR/queue.json"
TICKET_ID="$1"
```

Read ticket from `$QUEUE_FILE` (`.tickets[] | select(.id == $TICKET_ID)`).

### 2. Fetch full ticket details from Jira

Use MCP tool `mcp__claude_ai_Jira_Confluence__getJiraIssue` with ticket key to get full description, acceptance criteria, comments, and attachments.

If tool unavailable, fall back to:
```bash
acli jira workitem view "$TICKET_ID" --json
```

### 3. Set status to classifying

Update queue.json: `.tickets[] | select(.id == $TICKET_ID) | .status = "classifying"`

Call audit: `~/.claude/workflow/scripts/audit.sh "CLASSIFY" "$TICKET_ID started"`

### 4. Regenerate dashboard

```bash
~/.claude/workflow/scripts/update-dashboard.sh > /dev/null
```

### 5. Analyze the ticket

Evaluate these criteria:
- **Summary clarity**: Does the title describe what needs to change?
- **Description completeness**: Is there enough context to understand the change?
- **Acceptance criteria**: Are success conditions defined (or inferable)?
- **Scope**: Is this a single focused change, or does it require breakdown?
- **Dependencies**: Are there blocking dependencies mentioned?
- **Technical specificity**: Does it name files, modules, or behaviors specifically enough to locate in the codebase?

Classify as:
- **ready**: Can start implementation without further clarification
- **needs-clarification**: Missing critical info, ambiguous, or too broad
- **too-large**: Should be broken into subtasks first

### 6a. If READY

Write plan to `$WORKFLOW_DIR/plans/<TICKET-ID>.md`:

```markdown
# <TICKET-ID>: <title>

## Context
<why this change — from ticket description + acceptance criteria>

## Target repo
<best guess based on ticket context — Gusto/zenpayroll, Gusto/web, etc.>

## Files likely affected
- path/to/file.ts — what changes
- path/to/other.ts — what changes

## Implementation steps

Use GFM checkboxes so the dashboard can track progress. Implementer updates `[ ]` → `[x]` as each step completes.

- [ ] ...
- [ ] ...
- [ ] ...

## Verification
- How to test manually
- Tests to add/update

## Open questions (should be empty for ready tickets)
- none
```

Update queue.json:
- `.status = "awaiting-approval"`
- `.plan_path = "<absolute path>"`
- `.classification = "ready"`

Audit: `audit.sh "CLASSIFY" "$TICKET_ID → ready"`
Audit: `audit.sh "PLAN" "$TICKET_ID written to plans/<ticket>.md"`

**Thread convention:** post to `#your-automation-channel` (channel_id `YOUR_SLACK_CHANNEL_ID`). If the ticket already has `.slack_thread_ts` in queue.json, reply in that thread with `reply_broadcast: true` so it also surfaces in the channel. Otherwise create a new thread (no `thread_ts`, no `reply_broadcast`) and save the returned `message_ts` to `.slack_thread_ts`. Persist via `jq` like the wf-implement skill.

For the READY case, post:
```
📋 *<TICKET-ID>* classified READY — plan awaiting approval

<title>

Approve: `/wf-approve <TICKET-ID>`
Reject: `/wf-reject <TICKET-ID>`
Plan: file://<plan_path>
```
Channel ID: read from `$WORKFLOW_DIR/.env` `SLACK_CHANNEL_ID`

### 6b. If NEEDS-CLARIFICATION

Write draft to `$WORKFLOW_DIR/drafts/<TICKET-ID>.md`:

```markdown
# <TICKET-ID> — Clarification Request (DRAFT)

This ticket is missing information needed to implement safely.

## Missing information
- <specific gap 1>
- <specific gap 2>

## Draft comment (edit before posting)

> Hi <reporter>, thanks for the ticket. Before I pick this up, a few questions:
>
> 1. ...
> 2. ...
>
> Let me know and I'll get started.

## Action
Review and post the comment manually. Use `/wf-reject <TICKET-ID>` to remove from queue, or update the ticket and re-run `/wf-feed <TICKET-ID>` to reclassify.
```

Update queue.json:
- `.status = "needs-clarification"`
- `.draft_path = "<absolute path>"`
- `.classification = "needs-clarification"`

Audit: `audit.sh "CLASSIFY" "$TICKET_ID → needs-clarification"`
Audit: `audit.sh "DRAFT" "$TICKET_ID clarification written to drafts/<ticket>.md"`

Same threading rule as the ready case. Post to thread (create if needed, save `message_ts` to queue):
```
🔍 *<TICKET-ID>* needs clarification

<title>

Draft reply ready: file://<draft_path>
Reject: `/wf-reject <TICKET-ID>`
```

### 6c. If TOO-LARGE

Similar to needs-clarification, but draft suggests splitting:

```markdown
# <TICKET-ID> — Too Large (DRAFT)

This ticket should be broken into smaller subtasks before implementation.

## Suggested breakdown
- Subtask 1: ...
- Subtask 2: ...

## Draft comment
> Hi <reporter>, this ticket looks like it could benefit from being split into smaller subtasks:
> ...
```

Status: `.status = "needs-clarification"` (same state, different reason)

### 7. Regenerate dashboard

```bash
~/.claude/workflow/scripts/update-dashboard.sh > /dev/null
```

## Never

- Never post comments directly to Jira. Always write drafts for user review.
- Never modify repo files. This skill only reads tickets and writes plans/drafts.
- Never create branches or PRs.
- Never skip the audit log. Every state transition must be logged.

## Output

Report to user (brief):

```
<TICKET-ID>: classified <status>
Plan: <path> (if ready)
Draft: <path> (if needs-clarification)
```

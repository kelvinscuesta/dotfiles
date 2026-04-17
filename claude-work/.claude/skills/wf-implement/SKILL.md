---
name: wf-implement
description: Internal workflow skill. Implement an approved Jira ticket. Creates git worktree, implements the plan, commits, pushes, creates draft PR. Never merges or posts comments. Invoked by /wf-approve.
argument-hint: "<ticket-id>"
---

# wf-implement

Implement a previously classified and approved Jira ticket. Produces a draft PR for user review.

## Inputs

- `$1` = ticket ID (e.g., `PAY-38012`)

## Preconditions

- Ticket exists in `queue.json` with `.status == "awaiting-approval"` or `.status == "in-progress"` (set by `/wf-approve`)
- Plan exists at `plans/<ticket-id>.md`
- User has explicitly approved (do not run without approval)

## Reading the pending marker

The server writes `~/.claude/workflow/pending/implement/<ticket-id>.json` before invoking this skill. Check it for a `.force` boolean:

```bash
MARKER="$HOME/.claude/workflow/pending/implement/$1.json"
FORCE=$(jq -r '.force // false' "$MARKER" 2>/dev/null)
```

If `force == true`: **proceed with implementation even if the plan mentions blockers or dependencies**. Skip blocker pre-checks. User has explicitly overridden caution.

If `force == false` / unset: honor blocker pre-checks — abort cleanly if a blocker PR is still open.

## Slack thread for this implementation (IMPORTANT)

Before doing any work, **create a Slack thread** in `#your-automation-channel` for this ticket. Use MCP tool `mcp__claude_ai_Slack_Gusto_Offical__slack_send_message`:

```
channel_id: YOUR_SLACK_CHANNEL_ID
message: "🚀 *<TICKET-ID>* — implementation starting
         Plan: file://<plan_path>
         Force: <true|false>
         Worktree: <path>"
```

The tool returns `{ message_context: { message_ts: "<ts>" } }`. **Capture that `message_ts`** — it's the thread root.

**Persist the thread_ts to the queue** so subsequent runs (and the server) can reuse it:

```bash
jq --arg id "$TICKET_ID" --arg ts "$THREAD_TS" '.tickets |= map(if .id == $id then .slack_thread_ts = $ts else . end)' "$QUEUE_FILE" > /tmp/q.json && mv /tmp/q.json "$QUEUE_FILE"
```

If the ticket already has `.slack_thread_ts` from a previous run, **reuse it** — post new updates as thread replies instead of creating a new thread.

### Post updates to the thread at key milestones

Every meaningful transition gets a reply in the thread. Use the SAME `slack_send_message` tool with `thread_ts: "<captured ts>"` **AND `reply_broadcast: true`** so the reply is also visible in the channel (so the user doesn't have to open every thread to stay current):

- 🌱 Worktree created: branch name + path
- 📝 Plan steps in progress (1-2 at a time, not every single step)
- ✅ Verification passing (tsc, lint, tests)
- ❌ Verification failing + cause
- 📦 Commits made (subject lines only)
- 🚀 Draft PR created: URL + title
- ⚠️ Needs-human signal: the reason being recorded
- 🛑 Aborted: short reason

**Rules:**
- Keep thread replies short (≤300 chars each).
- No need to thread every tool call — think "milestone log", not transcript.
- On the very last message, summarize the outcome ("done / PR <url>" or "aborted: <reason>").
- If the Slack MCP call fails, log an audit `NOTIFY SLACK_FAIL` but do NOT abort the implementation.

## Procedure

### 1. Load ticket + plan

```bash
WORKFLOW_DIR="$HOME/.claude/workflow"
QUEUE_FILE="$WORKFLOW_DIR/queue.json"
TICKET_ID="$1"

TICKET=$(jq -c --arg id "$TICKET_ID" '.tickets[] | select(.id == $id)' "$QUEUE_FILE")
PLAN_PATH=$(echo "$TICKET" | jq -r '.plan_path')
```

If plan missing or status wrong, abort with clear error.

### 2. Determine target repo

Read from plan's "Target repo" section (set by classifier). If ambiguous, use ticket context and ask user before proceeding.

Common Gusto repos:
- `Gusto/zenpayroll` — Rails monolith
- `Gusto/web` — JS monorepo (React frontend)
- `Gusto/ai-platform-services` — AI services

**Load domain skills proactively.** Based on repo + plan content, invoke the relevant Gusto skills BEFORE touching code so conventions are applied correctly:

- Frontend (`Gusto/web`): `gusto-frontend:frontend-development`, `gusto-frontend:organize-app-files` (for NTR moves), `gusto-frontend:working-with-yarn-g-move`, `gusto-frontend:run-jest` for tests
- Backend (`Gusto/zenpayroll`): `gusto-backend:rspec-patterns`, `gusto-backend:packwerk-compliance`, `gusto-backend:run-rspec`, `gusto-backend:working-with-feature-flags` when FFs touched
- Before committing: `superpowers:verification-before-completion` — type-check + lint + tests must all pass
- Before creating PR: `superpowers:requesting-code-review`

### 3. Set status to in-progress

Update queue.json: `.status = "in-progress"`
Audit: `audit.sh "IMPLEMENT" "$TICKET_ID starting"`
Regen dashboard.

### 4. Create git worktree

Use `superpowers:using-git-worktrees` skill for isolation. Branch naming:

```
kelvin/<ticket-id>-<slug-from-title>
```

Example: `kelvin/PAY-38012-fix-payroll-rounding`

Worktree path: `~/workspace/<repo-name>-worktrees/<ticket-id>/`

Update queue.json:
- `.branch = "<branch-name>"`
- `.worktree_path = "<absolute path>"`
- `.pr_repo = "<owner/repo>"`

### 4.5. Optional: deep research before implementation

If the plan has "Open questions" or the task requires exploring codebase patterns:

1. Spawn an `Explore` subagent to research the relevant area
2. Write findings to `~/.claude/workflow/research/<TICKET-ID>.md`
3. Dashboard auto-detects and shows a Research link

### 4.6. Update plan checkboxes as you work

The plan under "Implementation steps" uses GFM checkboxes: `- [ ] step` / `- [x] step`.

After each step completes, **edit `<plan_path>` in-place** to check off the box. Dashboard parses the plan file every refresh — progress bar updates automatically.

Minimum: mark steps done as you finish them. Don't batch at the end.

### 5. Implement the plan

**CRITICAL:** Use `superpowers:test-driven-development` skill. No exceptions.

For each step in plan:
1. Write failing test first (or update existing test to fail)
2. Run test to confirm failure
3. Implement minimum code to pass
4. Run test to confirm pass
5. Refactor if needed
6. Commit with Conventional Commits format

### Diff visibility (MANDATORY)

After **every** Edit/Write tool call that modifies files in the worktree, run:

```bash
cd <worktree_path> && git --no-pager diff <changed-file>
```

After each commit, run:

```bash
cd <worktree_path> && git --no-pager show --stat HEAD && git --no-pager log --oneline -5
```

This streams the diff into the run log so the human reviewer can watch changes live without opening the worktree.

Commit format:
```
<type>(<scope>): <description>

[TICKET-ID]

<optional body>
```

Types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `style`, `ci`, `perf`

### 6. Push branch

```bash
cd <worktree_path>
git push -u origin <branch-name>
```

### 7. Create draft PR

**MANDATORY:** Invoke the `workflow-pr` skill via the `Skill` tool — do NOT hand-roll `gh pr create`. The skill:
- Discovers repo PR template (`.github/PULL_REQUEST_TEMPLATE.md`) and fills every section
- Handles title format, branch naming, draft flag, attribution
- Adds the "Leave a gif(t)" section

Pass the ticket ID as the argument:

```
Skill(skill: "workflow-pr", args: "<TICKET-ID>")
```

After the PR is created, **also invoke `session-summary`** via Skill so a structured summary doc is written.

Capture PR number and URL from `workflow-pr` output.

Update queue.json:
- `.status = "pr-created"`
- `.pr_number = <number>`

Audit: `audit.sh "IMPLEMENT" "$TICKET_ID PR #<number> created (draft)"`

### 8. Notify Slack

Via MCP `mcp__claude_ai_Slack_Gusto_Offical__slack_send_message` (record-keeping only):

```
🚀 *<TICKET-ID>* PR created (DRAFT)

<PR title>
<PR URL>

Branch: <branch-name>
Files changed: <N>
Commits: <M>
```

Channel ID from `$WORKFLOW_DIR/.env`.

### 9. Regenerate dashboard

```bash
~/.claude/workflow/scripts/update-dashboard.sh > /dev/null
```

## Failure handling

If implementation fails or you need human intervention (pre-commit hook blocks, test failure you can't resolve, missing dep, unclear path):

1. Revert queue status back to `awaiting-approval`
2. Audit: `audit.sh "IMPLEMENT" "$TICKET_ID FAILED: <reason>"`
3. Leave worktree in place for debugging
4. **Signal the server to open Ghostty for human inspection** — write a signal file:
   ```bash
   cat > "$HOME/.claude/workflow/pending/implement/$TICKET_ID.needs-human.json" <<EOF
   { "reason": "<short reason>", "timestamp": "$(date -u +%FT%TZ)" }
   EOF
   ```
   The server reads this after you exit and opens Ghostty at the worktree with a banner showing the reason.
5. Do NOT push or create PR
6. Do NOT transition Jira — leave it in its current state

## Jira transition

**Only transition Jira to "In Review" AFTER a draft PR is successfully created.** Do this via `acli`:

```bash
acli jira workitem transition --key "$TICKET_ID" --status "In Review" --yes
```

Do NOT transition on clean aborts, blocker detections, or anywhere else. The server no longer auto-transitions — the skill owns this decision.

## Never

- Never merge the PR
- Never take it out of draft
- Never post comments on Jira or GitHub
- Never force-push
- Never bypass TDD
- Never skip audit log entries

## Output

Brief report to user:

```
<TICKET-ID> implemented
Branch: <branch-name>
PR: #<number> — <url> (DRAFT)
Commits: <M>
Worktree: <path>
```

---
name: wf-analyze-pr
description: Internal workflow skill. Analyze new PR comments and produce local drafts (code changes + response text). NEVER posts comments or pushes code. Invoked by PR polling cron.
argument-hint: "<repo> <pr-number>"
---

# wf-analyze-pr

Analyze new comments on a PR and produce drafts for user review. Output:
- `changes.diff` — proposed code changes (not applied)
- `responses.md` — drafted reply text per comment
- `summary.md` — overview of comments and proposed fixes

**CRITICAL:** This skill NEVER posts comments, pushes code, or modifies any branches. It only reads and writes local draft files.

## Inputs

- `$1` = repo (e.g., `Gusto/zenpayroll`)
- `$2` = PR number (e.g., `332593`)

## Procedure

### 1. Load context

```bash
WORKFLOW_DIR="$HOME/.claude/workflow"
QUEUE_FILE="$WORKFLOW_DIR/queue.json"
REPO="$1"
PR_NUM="$2"
DRAFTS_DIR="$WORKFLOW_DIR/drafts/pr-${PR_NUM}"
mkdir -p "$DRAFTS_DIR"
```

Fetch PR record from queue.json → get `last_seen_comment_id`.

### 2. Fetch PR + new comments

```bash
# PR metadata
PR_META=$(gh api "repos/${REPO}/pulls/${PR_NUM}")

# PR diff
gh api "repos/${REPO}/pulls/${PR_NUM}" -H "Accept: application/vnd.github.v3.diff" > "$DRAFTS_DIR/pr.diff"

# New comments (via poll-prs.sh output or direct API call filtered by id > last_seen)
# Use data passed in from caller (poll-prs output) or refetch if needed
```

Comment sources:
- Inline review comments: `GET /repos/{owner}/{repo}/pulls/{pr}/comments` (has `.path`, `.line`)
- Issue-level comments: `GET /repos/{owner}/{repo}/issues/{pr}/comments` (top-level discussion)
- Reviews: `GET /repos/{owner}/{repo}/pulls/{pr}/reviews` (approval / request-changes with body)

Filter: `.user.type != "Bot"` AND `.id > last_seen_comment_id`.

### 3. Classify each comment

For each new comment, classify:
- **nit / style** — minor suggestion, easy to apply
- **bug / correctness** — must-fix before merge
- **question / clarification** — needs response, may or may not need code change
- **discussion** — broader architectural conversation
- **approval / acknowledgment** — reviewer approved, no action needed
- **future PR** — reviewer suggests follow-up work, not blocking

### 4. Write summary.md

```markdown
# PR #<number> — Comment Analysis

**Repo:** <repo>
**Title:** <pr title>
**URL:** <pr url>
**New comments:** <N>

## Comments overview

### [<type>] <commenter> on <path:line> (or "top-level")
> <comment body excerpt>

**Proposed action:** <describe what to change or respond>
**Category:** nit | bug | question | discussion | approval | future-PR

---

<one block per comment>
```

### 5. Write responses.md

For each comment that needs a reply:

```markdown
# PR #<number> — Draft Responses

## Reply to <commenter> (comment <id>)

**Context:** <what they said, short>
**URL:** <comment url>

**Draft response:**

> <your proposed response text>
>
> <code suggestions if applicable>

Post manually at: <url>

---

<one block per reply-needing comment>
```

### 6. Write changes.diff (if code changes needed)

If comments request code changes, produce unified diff showing proposed changes:

```bash
cd <pr branch checkout or worktree>
# Apply proposed fixes
# Generate diff
git diff > "$DRAFTS_DIR/changes.diff"
# Do NOT commit, do NOT push
git reset --hard HEAD  # revert so local repo stays clean
```

**Alternative (safer):** Produce the diff without touching any repo — emit a manually-crafted diff based on current file contents read via `gh api`.

### 7. Update queue.json

Update PR record:
- `.pending_comments` = number of new comments
- `.draft_path` = absolute path to `$DRAFTS_DIR`
- Do NOT update `last_seen_comment_id` yet — that happens when user marks drafts reviewed

Audit: `audit.sh "DRAFT" "PR #${PR_NUM} drafts written to drafts/pr-${PR_NUM}/"`

### 8. Notify Slack

**Thread convention:** post to `#your-automation-channel` (channel_id `YOUR_SLACK_CHANNEL_ID`). Each PR gets its own thread. Store `slack_thread_ts` on the PR record in queue.json:
- If `pr.slack_thread_ts` exists, reply in that thread **with `reply_broadcast: true`** so the reply also appears in the channel (user reads channel, not every thread)
- Otherwise, create a new thread (no `thread_ts`, no `reply_broadcast`) and persist the returned `message_ts`

Initial message:

```
💬 *PR #<number>* — <N> new comment(s)

<pr title>
<pr url>

Breakdown: <N nits, M questions, K bugs>
Drafts: file://<draft_path>
```

### 9. Regenerate dashboard

```bash
~/.claude/workflow/scripts/update-dashboard.sh > /dev/null
```

## Marking drafts as reviewed

Not automated. User runs `/wf-ack-pr <pr-number>` after posting replies to mark comments as seen (updates `last_seen_comment_id`). That skill is part of `/wf-*` user-facing commands.

## Never

- Never post comments via `gh api` or MCP
- Never push code
- Never modify any branch
- Never take a PR out of draft
- Never auto-apply diffs
- Never skip audit log

## Output

Brief report to user:

```
PR #<number>: <N> comments analyzed
Drafts: <path>
Categories: <breakdown>
```

#!/usr/bin/env bash
# SessionStart hook — if launched from headless workflow runner, emit a context
# preamble so the skill has ticket/plan/worktree data in view without re-reading
# marker files.
#
# Runner sets WF_HEADLESS=1 and exports WF_TICKET_ID, WF_PLAN_PATH, WF_WORKTREE,
# WF_REPO, WF_PR_NUMBER depending on kind. No-op for interactive sessions.

set -euo pipefail

[[ "${WF_HEADLESS:-0}" != "1" ]] && exit 0

# Disarm shell aliases that poison command output (e.g. cat -> bat adds ANSI
# codes to stdin-piped heredocs, which ends up in git commit messages).
# Also force plain output + no pagers for tools commonly run in skills.
export PAGER=cat
export GH_PAGER=cat
export GIT_PAGER=cat
export BAT_PAGING=never
export NO_COLOR=1
unset FORCE_COLOR CLICOLOR_FORCE

cat <<PREAMBLE
## Workflow headless context

- kind: ${WF_KIND:-?}
- ticket: ${WF_TICKET_ID:-n/a}
- repo: ${WF_REPO:-n/a}
- pr: ${WF_PR_NUMBER:-n/a}
- plan: ${WF_PLAN_PATH:-n/a}
- worktree: ${WF_WORKTREE:-n/a}
- cwd: $(pwd)

Rules: never merge, never exit draft, never post comments. Follow the skill
(wf-classify / wf-implement / wf-analyze-pr / wf-review-pr / wf-morning-brief) exactly.
Stream diffs after every Edit/Write. Use workflow-pr + session-summary skills for PR creation.

Slack channels:
- main (signal): env SLACK_CHANNEL_ID — brief posts, plans ready, PR created, failures
- firehose (noise, optional): env SLACK_CHANNEL_ID_FIREHOSE — per-step impl milestones, commits. If empty, noise → audit log only, never to main.

Workflow state path:
- \$WORKFLOW_DIR is set to \$HOME/.local/state/workflow (outside ~/.claude/ to avoid Claude's sensitive-path guard)
- ALL writes to drafts/, plans/, briefs/, research/, pending/, queue.json etc. must use \$WORKFLOW_DIR — never \$HOME/.claude/workflow
- If you write under ~/.claude/workflow/* the Write tool will be blocked by the sensitive-path guard (no amount of allow-list fixes this)

Queue writes (IMPORTANT):
- Use \$WORKFLOW_DIR/scripts/queue-mutate.sh '<jq-filter>' '<reason>' to update queue.json.
- The helper POSTs to the running workflow-server so writes are serialized with server mutations — eliminates races.
- On server-down it falls back to the legacy direct jq+mv write, so skills stay resilient.
- Do NOT hand-roll \`jq ... > /tmp/q.json && mv\` unless the helper itself errors.

Commit hygiene (IMPORTANT):
- NEVER use \`cat\` to build a commit body in this session — prefer \`git commit -m "subject" -m "body"\` or a temp file with \`git commit -F <file>\`.
- Shell aliases that wrap cat (e.g. bat) inject ANSI color codes into stdin-piped heredocs; those codes end up in commit messages.
- PAGER=cat + NO_COLOR=1 are set above to belt-and-suspenders this, but \`git commit -F\` is the most bulletproof pattern.
PREAMBLE

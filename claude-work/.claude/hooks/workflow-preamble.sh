#!/usr/bin/env bash
# SessionStart hook — if launched from headless workflow runner, emit a context
# preamble so the skill has ticket/plan/worktree data in view without re-reading
# marker files.
#
# Runner sets WF_HEADLESS=1 and exports WF_TICKET_ID, WF_PLAN_PATH, WF_WORKTREE,
# WF_REPO, WF_PR_NUMBER depending on kind. No-op for interactive sessions.

set -euo pipefail

[[ "${WF_HEADLESS:-0}" != "1" ]] && exit 0

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
(wf-classify / wf-implement / wf-analyze-pr) exactly. Stream diffs after every
Edit/Write. Use workflow-pr + session-summary skills for PR creation.
PREAMBLE

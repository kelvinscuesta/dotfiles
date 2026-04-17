#!/usr/bin/env bash
# Show quick status as a macOS notification.
set -euo pipefail

SCRIPTS="${HOME}/.claude/workflow-server/scripts"
STATUS=$("${SCRIPTS}/server-status.sh" 2>/dev/null || echo '{"running":false}')

RUNNING=$(echo "${STATUS}" | jq -r '.running')
TICKETS=$(echo "${STATUS}" | jq -r '.queue.tickets')
PRS=$(echo "${STATUS}" | jq -r '.queue.prs')
P_CLASSIFY=$(echo "${STATUS}" | jq -r '.pending.classify')
P_IMPLEMENT=$(echo "${STATUS}" | jq -r '.pending.implement')
P_ANALYZE=$(echo "${STATUS}" | jq -r '.pending.analyze_pr')
PENDING=$((P_CLASSIFY + P_IMPLEMENT + P_ANALYZE))

if [[ "${RUNNING}" == "true" ]]; then
  TITLE="🔧 Workflow running"
  MSG="${TICKETS} tickets · ${PRS} PRs · ${PENDING} pending"
else
  TITLE="🔧 Workflow stopped"
  MSG="${TICKETS} tickets · ${PRS} PRs (queue preserved)"
fi

osascript -e "display notification \"${MSG}\" with title \"${TITLE}\""

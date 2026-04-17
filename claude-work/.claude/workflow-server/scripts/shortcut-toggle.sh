#!/usr/bin/env bash
# Toggle workflow server — start if stopped, stop if running.
# Notifies via macOS notification.
set -euo pipefail

SCRIPTS="${HOME}/.claude/workflow-server/scripts"
STATUS=$("${SCRIPTS}/server-status.sh" 2>/dev/null || echo '{"running":false}')
RUNNING=$(echo "${STATUS}" | jq -r '.running')

if [[ "${RUNNING}" == "true" ]]; then
  "${SCRIPTS}/server-stop.sh"
  osascript -e 'display notification "Server stopped" with title "🔧 Workflow" sound name "Pop"'
else
  "${SCRIPTS}/server-start.sh"
  osascript -e 'display notification "Server starting…" with title "🔧 Workflow" sound name "Glass"'
fi

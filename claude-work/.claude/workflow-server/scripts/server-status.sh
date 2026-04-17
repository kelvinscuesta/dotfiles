#!/usr/bin/env bash
# Report server status as JSON.
# Output fields: running (bool), pid, uptime_s, started_at, queue counts.

set -euo pipefail

SERVER_DIR="${HOME}/.claude/workflow-server"
PID_FILE="${SERVER_DIR}/server.pid"
QUEUE_FILE="${HOME}/.claude/workflow/queue.json"
PENDING_DIR="${HOME}/.claude/workflow/pending"

RUNNING=false
PID=null
UPTIME_S=0
STARTED_AT=null

if [[ -f "${PID_FILE}" ]]; then
  P=$(cat "${PID_FILE}")
  if kill -0 "${P}" 2>/dev/null; then
    RUNNING=true
    PID=$P
    # macOS: ps -o etime= gives elapsed time since process start; convert to seconds
    ELAPSED=$(ps -p "${P}" -o etime= 2>/dev/null | awk '{$1=$1};1' || echo "")
    if [[ -n "${ELAPSED}" ]]; then
      # etime format: [[dd-]hh:]mm:ss
      UPTIME_S=$(awk -v t="${ELAPSED}" 'BEGIN {
        n = split(t, a, "-"); days = 0; rest = t
        if (n == 2) { days = a[1]; rest = a[2] }
        m = split(rest, b, ":")
        if (m == 3) { print (days*86400) + (b[1]*3600) + (b[2]*60) + b[3] }
        else if (m == 2) { print (days*86400) + (b[1]*60) + b[2] }
        else { print 0 }
      }')
      STARTED_AT=$(ps -p "${P}" -o lstart= 2>/dev/null | awk '{$1=$1};1' || echo "")
      STARTED_AT="\"${STARTED_AT}\""
    fi
  fi
fi

# Queue counts
TICKETS=0
BACKLOG=0
PRS=0
COMPLETED=0
PENDING_CLASSIFY=0
PENDING_IMPLEMENT=0
PENDING_ANALYZE=0
if [[ -f "${QUEUE_FILE}" ]]; then
  TICKETS=$(jq '.tickets | length' "${QUEUE_FILE}" 2>/dev/null || echo 0)
  BACKLOG=$(jq '.backlog | length' "${QUEUE_FILE}" 2>/dev/null || echo 0)
  PRS=$(jq '.prs | length' "${QUEUE_FILE}" 2>/dev/null || echo 0)
  COMPLETED=$(jq '.completed | length' "${QUEUE_FILE}" 2>/dev/null || echo 0)
fi
[[ -d "${PENDING_DIR}/classify" ]] && PENDING_CLASSIFY=$(find "${PENDING_DIR}/classify" -name '*.json' -not -name '*.tmp' -not -name '*.running.json' -not -name '*.failed.json' 2>/dev/null | wc -l | tr -d ' ')
[[ -d "${PENDING_DIR}/implement" ]] && PENDING_IMPLEMENT=$(find "${PENDING_DIR}/implement" -name '*.json' -not -name '*.tmp' -not -name '*.running.json' -not -name '*.failed.json' 2>/dev/null | wc -l | tr -d ' ')
[[ -d "${PENDING_DIR}/analyze-pr" ]] && PENDING_ANALYZE=$(find "${PENDING_DIR}/analyze-pr" -name '*.json' -not -name '*.tmp' -not -name '*.running.json' -not -name '*.failed.json' 2>/dev/null | wc -l | tr -d ' ')

cat <<EOF
{
  "running": ${RUNNING},
  "pid": ${PID},
  "uptime_s": ${UPTIME_S},
  "started_at": ${STARTED_AT},
  "queue": {
    "tickets": ${TICKETS},
    "backlog": ${BACKLOG},
    "prs": ${PRS},
    "completed": ${COMPLETED}
  },
  "pending": {
    "classify": ${PENDING_CLASSIFY},
    "implement": ${PENDING_IMPLEMENT},
    "analyze_pr": ${PENDING_ANALYZE}
  }
}
EOF

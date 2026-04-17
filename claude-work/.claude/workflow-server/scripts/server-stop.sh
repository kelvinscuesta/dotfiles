#!/usr/bin/env bash
# Stop the workflow server.

set -euo pipefail

SERVER_DIR="${HOME}/.claude/workflow-server"
PID_FILE="${SERVER_DIR}/server.pid"

if [[ ! -f "${PID_FILE}" ]]; then
  echo "not running (no pid file)"
  exit 0
fi

PID=$(cat "${PID_FILE}")
if ! kill -0 "${PID}" 2>/dev/null; then
  echo "stale pid ${PID} — cleaning up"
  rm -f "${PID_FILE}"
  exit 0
fi

kill -TERM "${PID}"

# Wait up to 5s for graceful shutdown
for _ in {1..10}; do
  if ! kill -0 "${PID}" 2>/dev/null; then
    rm -f "${PID_FILE}"
    echo "stopped (pid=${PID})"
    exit 0
  fi
  sleep 0.5
done

# Force kill
kill -KILL "${PID}" 2>/dev/null || true
rm -f "${PID_FILE}"
echo "force-killed (pid=${PID})"

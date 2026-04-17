#!/usr/bin/env bash
# Start the workflow server in the background.
# Idempotent: no-op if already running.

set -euo pipefail

SERVER_DIR="${HOME}/.claude/workflow-server"
LOG_DIR="${SERVER_DIR}/logs"
PID_FILE="${SERVER_DIR}/server.pid"
STDOUT_LOG="${LOG_DIR}/stdout.log"
STDERR_LOG="${LOG_DIR}/stderr.log"
ENV_FILE="${SERVER_DIR}/.env"
BUN_BIN="${BUN_BIN:-${HOME}/.local/share/mise/installs/bun/1.3.12/bin/bun}"

mkdir -p "${LOG_DIR}"

# Load .env if present (server-specific overrides)
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

# Check if already running
if [[ -f "${PID_FILE}" ]]; then
  PID=$(cat "${PID_FILE}")
  if kill -0 "${PID}" 2>/dev/null; then
    echo "already running (pid=${PID})"
    exit 0
  fi
  # stale pid file
  rm -f "${PID_FILE}"
fi

# Spawn detached, redirect logs
cd "${SERVER_DIR}"
nohup "${BUN_BIN}" run src/server.ts \
  > "${STDOUT_LOG}" \
  2> "${STDERR_LOG}" \
  < /dev/null &

PID=$!
echo "${PID}" > "${PID_FILE}"
disown

echo "started (pid=${PID})"
echo "logs: ${STDOUT_LOG}"

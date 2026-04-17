#!/usr/bin/env bash
# Send notification to Slack via webhook
# Usage: notify-slack.sh <emoji> <title> [detail]
# Example: notify-slack.sh "📋" "PAY-38012 classified ready" "Plan awaiting approval"

set -euo pipefail

WORKFLOW_DIR="${HOME}/.claude/workflow"
ENV_FILE="${WORKFLOW_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} not found" >&2
  exit 1
fi

source "${ENV_FILE}"

if [[ -z "${SLACK_WEBHOOK_URL:-}" || "${SLACK_WEBHOOK_URL}" == *"XXXXX"* ]]; then
  echo "WARN: SLACK_WEBHOOK_URL not configured, skipping notification" >&2
  exit 0
fi

EMOJI="${1:?Usage: notify-slack.sh <emoji> <title> [detail]}"
TITLE="${2:?Usage: notify-slack.sh <emoji> <title> [detail]}"
DETAIL="${3:-}"

TEXT="${EMOJI} *${TITLE}*"
if [[ -n "${DETAIL}" ]]; then
  TEXT="${TEXT}\n${DETAIL}"
fi

PAYLOAD=$(jq -n --arg text "${TEXT}" '{"text": $text}')

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" \
  "${SLACK_WEBHOOK_URL}")

if [[ "${HTTP_CODE}" != "200" ]]; then
  echo "ERROR: Slack webhook returned HTTP ${HTTP_CODE}" >&2
  exit 1
fi

# Log notification
"${WORKFLOW_DIR}/scripts/audit.sh" "NOTIFY" "Slack: ${TITLE}"

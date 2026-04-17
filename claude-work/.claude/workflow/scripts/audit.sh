#!/usr/bin/env bash
# Append timestamped entry to audit log
# Usage: audit.sh <ACTION> <message>
# Example: audit.sh "POLL:JIRA" "found 2 new tickets: PAY-38012, PAY-38015"

set -euo pipefail

WORKFLOW_DIR="${HOME}/.claude/workflow"
AUDIT_LOG="${WORKFLOW_DIR}/audit.log"
ACTION="${1:?Usage: audit.sh <ACTION> <message>}"
MESSAGE="${2:?Usage: audit.sh <ACTION> <message>}"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S)"

echo "${TIMESTAMP} [${ACTION}] ${MESSAGE}" >> "${AUDIT_LOG}"

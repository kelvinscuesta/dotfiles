#!/usr/bin/env bash
# Poll Jira for tickets (active sprint + backlog)
# Outputs JSON to stdout: {"active": [...], "backlog": [...]}
# Active = in open sprint, Backlog = assigned/reported but not in sprint
# Usage: poll-jira.sh [--verbose]

set -euo pipefail

WORKFLOW_DIR="${HOME}/.claude/workflow"
ENV_FILE="${WORKFLOW_DIR}/.env"
QUEUE_FILE="${WORKFLOW_DIR}/queue.json"
AUDIT="${WORKFLOW_DIR}/scripts/audit.sh"

VERBOSE=0
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1

log() {
  if [[ "${VERBOSE}" == "1" ]]; then
    echo "[poll-jira] $*" >&2
  fi
}

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} not found" >&2
  exit 1
fi
source "${ENV_FILE}"

FIELDS="key,summary,status,issuetype,priority,reporter,assignee,labels"

fetch_and_normalize() {
  local jql="$1"
  local raw
  raw=$(acli jira workitem search --jql "${jql}" --json --limit 50 --fields "${FIELDS}" 2>&1 || echo "[]")
  # If acli printed error, return empty
  if ! echo "${raw}" | jq . >/dev/null 2>&1; then
    log "JQL failed: ${jql}"
    log "Output: ${raw}"
    echo "[]"
    return
  fi
  echo "${raw}" | jq '[.[] | {
    id: .key,
    title: .fields.summary,
    status: .fields.status.name,
    issue_type: .fields.issuetype.name,
    priority: (.fields.priority.name // "none"),
    assignee_email: (.fields.assignee.emailAddress // null),
    reporter_email: (.fields.reporter.emailAddress // null),
    labels: (.fields.labels // []),
    url: ("https://gustohq.atlassian.net/browse/" + .key)
  }]'
}

# Active: in open sprint
JQL_ACTIVE='(assignee = currentUser() OR reporter = currentUser()) AND statusCategory != Done AND sprint in openSprints()'
# Backlog: assigned/reported, not in any open sprint
JQL_BACKLOG='(assignee = currentUser() OR reporter = currentUser()) AND statusCategory != Done AND (sprint is EMPTY OR sprint not in openSprints())'

log "Fetching active sprint tickets..."
ACTIVE=$(fetch_and_normalize "${JQL_ACTIVE}")
ACTIVE_COUNT=$(echo "${ACTIVE}" | jq 'length')
log "Active tickets: ${ACTIVE_COUNT}"

log "Fetching backlog tickets..."
BACKLOG=$(fetch_and_normalize "${JQL_BACKLOG}")
BACKLOG_COUNT=$(echo "${BACKLOG}" | jq 'length')
log "Backlog tickets: ${BACKLOG_COUNT}"

# Diff against queue (both active and backlog sections)
EXISTING_IDS=$(jq -r '[.tickets[].id, (.backlog // [])[].id, .completed[].id] | .[]' "${QUEUE_FILE}" 2>/dev/null | sort -u)
EXISTING_JSON=$(echo "${EXISTING_IDS}" | jq -R . | jq -s .)

NEW_ACTIVE=$(echo "${ACTIVE}" | jq --argjson existing "${EXISTING_JSON}" \
  '[.[] | select(.id as $id | ($existing | index($id) | not))]')

NEW_BACKLOG=$(echo "${BACKLOG}" | jq --argjson existing "${EXISTING_JSON}" \
  '[.[] | select(.id as $id | ($existing | index($id) | not))]')

NEW_ACTIVE_COUNT=$(echo "${NEW_ACTIVE}" | jq 'length')
NEW_BACKLOG_COUNT=$(echo "${NEW_BACKLOG}" | jq 'length')
log "New active: ${NEW_ACTIVE_COUNT}, new backlog: ${NEW_BACKLOG_COUNT}"

if [[ "${NEW_ACTIVE_COUNT}" -gt 0 ]]; then
  IDS=$(echo "${NEW_ACTIVE}" | jq -r '.[].id' | paste -sd, -)
  "${AUDIT}" "POLL:JIRA" "found ${NEW_ACTIVE_COUNT} new active tickets: ${IDS}"
fi
if [[ "${NEW_BACKLOG_COUNT}" -gt 0 ]]; then
  IDS=$(echo "${NEW_BACKLOG}" | jq -r '.[].id' | paste -sd, -)
  "${AUDIT}" "POLL:JIRA" "found ${NEW_BACKLOG_COUNT} new backlog tickets: ${IDS}"
fi
if [[ "${NEW_ACTIVE_COUNT}" -eq 0 && "${NEW_BACKLOG_COUNT}" -eq 0 ]]; then
  "${AUDIT}" "POLL:JIRA" "no new tickets"
fi

jq -n --argjson active "${NEW_ACTIVE}" --argjson backlog "${NEW_BACKLOG}" \
  '{active: $active, backlog: $backlog}'

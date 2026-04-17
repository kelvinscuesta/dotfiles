#!/usr/bin/env bash
# <bitbar.title>Workflow Server</bitbar.title>
# <bitbar.version>v1.1</bitbar.version>
# <bitbar.author>kelvin</bitbar.author>
# <bitbar.desc>Start/stop workflow server + queue + running task logs + ticket/PR links.</bitbar.desc>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>

set -euo pipefail

SERVER_DIR="${HOME}/.claude/workflow-server"
WORKFLOW_DIR="${HOME}/.claude/workflow"
SCRIPTS="${SERVER_DIR}/scripts"
LOG_DIR="${SERVER_DIR}/logs"
DASHBOARD_URL="http://localhost:3000"
STATUS=$("${SCRIPTS}/server-status.sh" 2>/dev/null || echo '{"running":false}')

RUNNING=$(echo "${STATUS}" | jq -r '.running')
PID=$(echo "${STATUS}" | jq -r '.pid // "-"')
UPTIME_S=$(echo "${STATUS}" | jq -r '.uptime_s // 0')
TICKETS_N=$(echo "${STATUS}" | jq -r '.queue.tickets // 0')
BACKLOG_N=$(echo "${STATUS}" | jq -r '.queue.backlog // 0')
PRS_N=$(echo "${STATUS}" | jq -r '.queue.prs // 0')
P_CLASSIFY=$(echo "${STATUS}" | jq -r '.pending.classify // 0')
P_IMPLEMENT=$(echo "${STATUS}" | jq -r '.pending.implement // 0')
P_ANALYZE=$(echo "${STATUS}" | jq -r '.pending.analyze_pr // 0')
PENDING_TOTAL=$((P_CLASSIFY + P_IMPLEMENT + P_ANALYZE))

format_uptime() {
  local s=$1
  if (( s < 60 )); then echo "${s}s"
  elif (( s < 3600 )); then echo "$((s/60))m"
  elif (( s < 86400 )); then echo "$((s/3600))h $((s%3600/60))m"
  else echo "$((s/86400))d $((s%86400/3600))h"
  fi
}

# Find active implement/classify run (if any)
RUNNING_LOG=""
RUNNING_KIND=""
RUNNING_TICKET=""
RUNNING_SIDECAR=""
for kind in implement classify analyze-pr; do
  for sc in "${WORKFLOW_DIR}/pending/${kind}"/*.running.json; do
    [[ -e "$sc" ]] || continue
    RUNNING_SIDECAR="$sc"
    RUNNING_KIND="$kind"
    RUNNING_TICKET=$(basename "$sc" .running.json)
    RUNNING_LOG=$(jq -r '.log_path' "$sc" 2>/dev/null || echo "")
    break 2
  done
done

# Menu bar label
if [[ "${RUNNING}" == "true" ]]; then
  if [[ -n "${RUNNING_TICKET}" ]]; then
    echo "⚙︎ ${RUNNING_TICKET}"
  elif (( PENDING_TOTAL > 0 )); then
    echo "⏳ ${PENDING_TOTAL}"
  else
    echo "●"
  fi
else
  echo "○"
fi

echo "---"

# Server status
if [[ "${RUNNING}" == "true" ]]; then
  UPTIME=$(format_uptime "${UPTIME_S}")
  echo "Server running · pid ${PID} · up ${UPTIME} | color=green"
else
  echo "Server stopped | color=gray"
fi

echo "---"

# Current run block
if [[ -n "${RUNNING_TICKET}" ]]; then
  echo "⚙︎ ${RUNNING_KIND}: ${RUNNING_TICKET} | color=cyan"
  if [[ -n "${RUNNING_LOG}" && -f "${RUNNING_LOG}" ]]; then
    # Tail last 15 lines of the run log
    tail -15 "${RUNNING_LOG}" 2>/dev/null | while IFS= read -r line; do
      # Strip ANSI, trim, escape pipe chars (SwiftBar separator)
      clean=$(echo "${line}" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/|/│/g')
      # Truncate long lines
      clean="${clean:0:100}"
      [[ -z "${clean}" ]] && continue
      echo "-- ${clean} | font=Menlo size=11 color=#888"
    done
    echo "-----"
    echo "-- 📂 Open full log | shell=/usr/bin/open param1=${RUNNING_LOG} terminal=false"
  fi
  echo "---"
fi

# Queue summary
echo "Queue"
echo "-- Active: ${TICKETS_N} · Backlog: ${BACKLOG_N} · PRs: ${PRS_N} | font=Menlo size=12"
if (( PENDING_TOTAL > 0 )); then
  echo "-- Pending: ${P_CLASSIFY} classify · ${P_IMPLEMENT} implement · ${P_ANALYZE} analyze | color=orange"
fi

# Active tickets submenu
if (( TICKETS_N > 0 )); then
  echo "Active tickets (${TICKETS_N})"
  jq -c '.tickets[] | {id, title, status, url}' "${WORKFLOW_DIR}/queue.json" 2>/dev/null | while read -r line; do
    t_id=$(echo "$line" | jq -r '.id')
    t_title=$(echo "$line" | jq -r '.title' | sed 's/|/│/g')
    t_title="${t_title:0:70}"
    t_status=$(echo "$line" | jq -r '.status')
    t_url=$(echo "$line" | jq -r '.url')
    # Badge dot for status
    case "$t_status" in
      new) dot="○" ;;
      classifying) dot="⚙" ;;
      ready|awaiting-approval) dot="◔" ;;
      needs-clarification) dot="?" ;;
      in-progress) dot="⚙" ;;
      pr-created) dot="✓" ;;
      *) dot="·" ;;
    esac
    echo "-- ${dot} ${t_id} — ${t_title} | href=${t_url} font=Menlo size=12"
    echo "---- status: ${t_status} | font=Menlo size=11 color=#888"
    echo "---- Open in dashboard | href=${DASHBOARD_URL}/#${t_id}"
    if [[ -f "${WORKFLOW_DIR}/plans/${t_id}.md" ]]; then
      echo "---- Plan | href=${DASHBOARD_URL}/plan/${t_id}"
    fi
    if [[ -f "${WORKFLOW_DIR}/research/${t_id}.md" ]]; then
      echo "---- Research | href=${DASHBOARD_URL}/research/${t_id}"
    fi
  done
fi

# Open PRs submenu
if (( PRS_N > 0 )); then
  echo "Open PRs (${PRS_N})"
  jq -c '.prs[] | {repo, number, title, url, ci: .ci.status, is_draft}' "${WORKFLOW_DIR}/queue.json" 2>/dev/null | while read -r line; do
    p_num=$(echo "$line" | jq -r '.number')
    p_repo=$(echo "$line" | jq -r '.repo')
    p_title=$(echo "$line" | jq -r '.title' | sed 's/|/│/g')
    p_title="${p_title:0:70}"
    p_url=$(echo "$line" | jq -r '.url')
    p_ci=$(echo "$line" | jq -r '.ci // "unknown"')
    p_draft=$(echo "$line" | jq -r '.is_draft // false')
    case "$p_ci" in
      pass) ci_glyph="✓" ;;
      fail) ci_glyph="✗" ;;
      pending) ci_glyph="⏳" ;;
      *) ci_glyph="·" ;;
    esac
    draft_tag=""
    [[ "$p_draft" == "true" ]] && draft_tag=" [draft]"
    echo "-- ${ci_glyph} #${p_num}${draft_tag} — ${p_title} | href=${p_url} font=Menlo size=12"
    echo "---- ${p_repo} | font=Menlo size=11 color=#888"
    echo "---- CI: ${p_ci} | color=#888"
  done
fi

echo "---"

# Actions
echo "📊 Dashboard | href=${DASHBOARD_URL}"
if [[ "${RUNNING}" == "true" ]]; then
  echo "Logs"
  echo "-- Server stdout | shell=/usr/bin/open param1=${LOG_DIR}/stdout.log terminal=false"
  echo "-- Server stderr | shell=/usr/bin/open param1=${LOG_DIR}/stderr.log terminal=false"
  echo "-- Logs folder | shell=/usr/bin/open param1=${LOG_DIR} terminal=false"
  echo "-- Audit log | shell=/usr/bin/open param1=${WORKFLOW_DIR}/audit.log terminal=false"
  echo "-- Tail stdout (Ghostty) | shell=${SCRIPTS}/shortcut-logs.sh terminal=false"
  echo "---"
  echo "⚡ Drain Pending | shell=/usr/bin/curl param1=-X param2=POST param3=${DASHBOARD_URL}/action/drain terminal=false refresh=true"
  echo "◼ Stop Server | shell=${SCRIPTS}/server-stop.sh terminal=false refresh=true"
  echo "↻ Restart Server | shell=bash param1=-c param2=\"'${SCRIPTS}/server-stop.sh && ${SCRIPTS}/server-start.sh'\" terminal=false refresh=true"
else
  echo "▶ Start Server | shell=${SCRIPTS}/server-start.sh terminal=false refresh=true"
fi
echo "---"
echo "Refresh | refresh=true"

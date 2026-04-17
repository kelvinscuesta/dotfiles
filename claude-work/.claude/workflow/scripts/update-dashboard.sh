#!/usr/bin/env bash
# Generate status.html from template + queue.json + audit.log
# Usage: update-dashboard.sh

set -euo pipefail

WORKFLOW_DIR="${WORKFLOW_DIR:-${HOME}/.claude/workflow}"
QUEUE_FILE="${QUEUE_FILE:-${WORKFLOW_DIR}/queue.json}"
AUDIT_LOG="${AUDIT_LOG:-${WORKFLOW_DIR}/audit.log}"
TEMPLATE="${TEMPLATE:-${WORKFLOW_DIR}/templates/status.html}"
OUTPUT="${STATUS_HTML:-${WORKFLOW_DIR}/status.html}"

# Escape for HTML (&, <, >, ", ')
html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

# Per-item activity: show only actions where this item is the PRIMARY subject
# Whitelist actions per card type. Dedup consecutive identical messages.
activity_for() {
  local key="$1"
  local max="${2:-5}"
  if [[ ! -f "${AUDIT_LOG}" ]]; then return; fi

  # Whitelisted per-item actions (exclude POLL rollups, START/STOP, etc.)
  local actions='CLASSIFY|PLAN|APPROVE|REJECT|IMPLEMENT|FEED|DRAFT|CLEANUP|ACK|NOTIFY'

  # Match only lines where action is whitelisted AND key appears in message
  grep -E "\[(${actions})\]" "${AUDIT_LOG}" 2>/dev/null \
    | grep -F "${key}" \
    | awk '{
        msg = substr($0, index($0, $2))
        if (msg != prev) { print; prev = msg }
      }' \
    | tail -"${max}" \
    | while IFS= read -r line; do
        local ts="${line%% *}"
        local rest="${line#* }"
        local action="${rest%% *}"
        local msg="${rest#* }"
        local short_ts="${ts##*T}"; short_ts="${short_ts:0:5}"
        local iso="${ts}Z"
        echo "<div class=\"entry\"><span class=\"ts\" data-ts=\"${iso}\">${short_ts}</span><span class=\"action\">${action}</span>$(echo "${msg}" | html_escape)</div>"
      done
}

render_ticket_card() {
  local item="$1" status_badge="$2"
  local id title url priority issue_type status
  id=$(echo "${item}" | jq -r '.id')
  title=$(echo "${item}" | jq -r '.title')
  url=$(echo "${item}" | jq -r '.url')
  priority=$(echo "${item}" | jq -r '.priority // "none"')
  issue_type=$(echo "${item}" | jq -r '.issue_type // "Task"')
  status=$(echo "${item}" | jq -r '.status // "unknown"')

  local extra_badges="<span class=\"badge\">$(echo "${issue_type}" | html_escape)</span><span class=\"badge\">$(echo "${priority}" | html_escape)</span>"

  # Run-state badges (from sidecars in ~/.claude/workflow/pending/)
  local pending_base="${WORKFLOW_DIR}/pending"
  local running_log=""
  for kind_dir in classify implement; do
    if [[ -f "${pending_base}/${kind_dir}/${id}.running.json" ]]; then
      extra_badges+="<span class=\"badge run-active\">⚙ ${kind_dir}ing</span>"
      running_log=$(jq -r '.log_path' "${pending_base}/${kind_dir}/${id}.running.json" 2>/dev/null || echo "")
    elif [[ -f "${pending_base}/${kind_dir}/${id}.failed.json" ]]; then
      extra_badges+="<span class=\"badge run-failed\">✗ ${kind_dir} failed</span>"
    fi
  done
  local activity
  activity=$(activity_for "${id}")

  local added_at approved_at
  added_at=$(echo "${item}" | jq -r '.added_at // ""')
  approved_at=$(echo "${item}" | jq -r '.approved_at // ""')

  local dl_rows="<dt>Type</dt><dd>$(echo "${issue_type}" | html_escape)</dd>"
  dl_rows+="<dt>Priority</dt><dd>$(echo "${priority}" | html_escape)</dd>"
  dl_rows+="<dt>Status</dt><dd>$(echo "${status}" | html_escape)</dd>"
  dl_rows+="<dt>Jira</dt><dd><a href=\"${url}\" target=\"_blank\">${id}</a></dd>"
  if [[ -n "${added_at}" && "${added_at}" != "null" ]]; then
    local added_short="${added_at%T*}"
    dl_rows+="<dt>Added</dt><dd><span data-ts=\"${added_at}\">${added_short}</span></dd>"
  fi
  if [[ -n "${approved_at}" && "${approved_at}" != "null" ]]; then
    local appr_short="${approved_at%T*}"
    dl_rows+="<dt>Approved</dt><dd><span data-ts=\"${approved_at}\">${appr_short}</span></dd>"
  fi

  local plan_path draft_path pr_number pr_repo branch
  plan_path=$(echo "${item}" | jq -r '.plan_path // ""')
  draft_path=$(echo "${item}" | jq -r '.draft_path // ""')
  pr_number=$(echo "${item}" | jq -r '.pr_number // ""')
  pr_repo=$(echo "${item}" | jq -r '.pr_repo // ""')
  branch=$(echo "${item}" | jq -r '.branch // ""')

  if [[ -n "${branch}" && "${branch}" != "null" ]]; then
    local repo_for_branch="${pr_repo}"
    [[ -z "${repo_for_branch}" || "${repo_for_branch}" == "null" ]] && repo_for_branch="Gusto/zenpayroll"
    dl_rows+="<dt>Branch</dt><dd><a href=\"https://github.com/${repo_for_branch}/tree/${branch}\" target=\"_blank\"><code>${branch}</code></a></dd>"
  fi
  if [[ -n "${plan_path}" && "${plan_path}" != "null" ]]; then
    dl_rows+="<dt>Plan</dt><dd><a href=\"/plan/${id}\" target=\"_blank\">view plan →</a></dd>"
    # Todo progress: count [ ] vs [x]
    if [[ -f "${plan_path}" ]]; then
      local total_todos checked_todos
      total_todos=$(grep -cE '^[[:space:]]*[-*][[:space:]]+\[[x ]\]' "${plan_path}" 2>/dev/null | tr -d '[:space:]')
      checked_todos=$(grep -cE '^[[:space:]]*[-*][[:space:]]+\[x\]' "${plan_path}" 2>/dev/null | tr -d '[:space:]')
      : "${total_todos:=0}"
      : "${checked_todos:=0}"
      if [[ "${total_todos}" -gt 0 ]]; then
        local pct=$(( checked_todos * 100 / total_todos ))
        local todo_items
        todo_items=$(awk '
          /^[[:space:]]*[-*][[:space:]]+\[[x ]\]/ {
            done = (index($0, "[x]") > 0)
            sub(/^[[:space:]]*[-*][[:space:]]+\[[x ]\][[:space:]]*/, "")
            gsub(/&/, "\\&amp;"); gsub(/</, "\\&lt;"); gsub(/>/, "\\&gt;")
            cls = done ? "done" : ""
            mark = done ? "✓" : "○"
            printf "<li class=\"%s\"><span class=\"mark\">%s</span><span>%s</span></li>", cls, mark, $0
          }
        ' "${plan_path}")
        dl_rows+="<dt>Progress</dt><dd><div style=\"display:flex;align-items:center;gap:8px\"><div style=\"flex:1;height:6px;background:var(--bg);border-radius:3px;overflow:hidden\"><div style=\"width:${pct}%;height:100%;background:var(--success);transition:width 0.3s\"></div></div><span style=\"font-size:11px;color:var(--text-muted)\">${checked_todos}/${total_todos}</span></div><details class=\"todos\"><summary>Implementation steps</summary><ul class=\"todo-list\">${todo_items}</ul></details></dd>"
      fi
    fi
  fi
  [[ -n "${draft_path}" && "${draft_path}" != "null" ]] && dl_rows+="<dt>Draft</dt><dd><a href=\"/draft/${id}\" target=\"_blank\">view draft →</a></dd>"
  # Research link if file exists
  if [[ -f "${WORKFLOW_DIR}/research/${id}.md" ]]; then
    dl_rows+="<dt>Research</dt><dd><a href=\"/research/${id}\" target=\"_blank\">view research →</a></dd>"
  fi
  if [[ -n "${pr_number}" && "${pr_number}" != "null" && -n "${pr_repo}" && "${pr_repo}" != "null" ]]; then
    dl_rows+="<dt>PR</dt><dd><a href=\"https://github.com/${pr_repo}/pull/${pr_number}\" target=\"_blank\">#${pr_number}</a></dd>"
  fi

  local esc_id esc_title
  esc_id=$(echo "${id}" | html_escape)
  esc_title=$(echo "${title}" | html_escape)

  # Action buttons based on current ticket status
  local actions=""
  local classification
  classification=$(echo "${item}" | jq -r '.classification // ""')
  case "${status}" in
    awaiting-approval)
      actions="<button class=\"action-btn approve\" data-action=\"approve\" data-id=\"${esc_id}\">✓ Approve</button>"
      if [[ "${classification}" == "ready-blocked" ]]; then
        actions+="<button class=\"action-btn force\" data-action=\"force-approve\" data-id=\"${esc_id}\" title=\"Bypass blocker check\">⚡ Force Approve</button>"
      fi
      actions+="<button class=\"action-btn reject\" data-action=\"reject\" data-id=\"${esc_id}\">✗ Reject</button><button class=\"action-btn\" data-action=\"reclassify\" data-id=\"${esc_id}\">↻ Reclassify</button>"
      ;;
    new|classifying)
      actions="<button class=\"action-btn reject\" data-action=\"reject\" data-id=\"${esc_id}\">✗ Reject</button>"
      ;;
    ready|needs-clarification)
      actions="<button class=\"action-btn\" data-action=\"reclassify\" data-id=\"${esc_id}\">↻ Reclassify</button><button class=\"action-btn reject\" data-action=\"reject\" data-id=\"${esc_id}\">✗ Reject</button>"
      ;;
    in-progress|pr-created)
      actions="<button class=\"action-btn reject\" data-action=\"reject\" data-id=\"${esc_id}\">✗ Abandon</button>"
      ;;
  esac

  local actions_html=""
  [[ -n "${actions}" ]] && actions_html="<div class=\"card-actions\">${actions}</div>"

  # Live log viewer if a run is active for this ticket
  local live_log_html=""
  if [[ -n "${running_log}" && "${running_log}" != "null" ]]; then
    local log_filename
    log_filename=$(basename "${running_log}")
    live_log_html="<div class=\"live-log\" data-log=\"${log_filename}\">
      <h4>🖥 Live log <span class=\"log-name\">${log_filename}</span></h4>
      <pre class=\"log-body\"></pre>
    </div>"
  fi

  cat <<EOF
<div class="card" title="${esc_id}: ${esc_title}">
  <div class="card-header">
    <div class="card-title"><span class="caret">▸</span> ${esc_id}</div>
    <div class="card-subtitle" title="${esc_title}">${esc_title}</div>
    <div class="card-badges">${status_badge}${extra_badges}</div>
  </div>
  <div class="card-body">
    <dl>${dl_rows}</dl>
    ${actions_html}
    ${live_log_html}
    <div class="activity">
      <h4>Activity</h4>
      ${activity:-<div class=\"entry\">no activity yet</div>}
    </div>
  </div>
</div>
EOF
}

render_pr_card() {
  local item="$1" status_badge="$2"
  local number title repo pending url draft_path
  number=$(echo "${item}" | jq -r '.number')
  title=$(echo "${item}" | jq -r '.title')
  repo=$(echo "${item}" | jq -r '.repo')
  pending=$(echo "${item}" | jq -r '.pending_comments // 0')
  url=$(echo "${item}" | jq -r '.url')
  draft_path=$(echo "${item}" | jq -r '.draft_path // ""')

  local extra_badges="<span class=\"badge\">$(echo "${repo}" | html_escape)</span>"
  [[ "${pending}" -gt 0 ]] && extra_badges+="<span class=\"badge comments\">${pending} comments</span>"

  # CI badge
  local ci_status ci_pass ci_fail ci_pending ci_total
  ci_status=$(echo "${item}" | jq -r '.ci.status // "unknown"')
  ci_pass=$(echo "${item}" | jq -r '.ci.pass // 0')
  ci_fail=$(echo "${item}" | jq -r '.ci.fail // 0')
  ci_pending=$(echo "${item}" | jq -r '.ci.pending // 0')
  ci_total=$(echo "${item}" | jq -r '.ci.total // 0')
  case "${ci_status}" in
    pass)    extra_badges+="<span class=\"badge ci-pass\">CI ✓ ${ci_pass}/${ci_total}</span>" ;;
    fail)    extra_badges+="<span class=\"badge ci-fail\">CI ✗ ${ci_fail} failing</span>" ;;
    pending) extra_badges+="<span class=\"badge ci-pending\">CI ⏳ ${ci_pending} pending</span>" ;;
    none)    extra_badges+="<span class=\"badge\">no CI</span>" ;;
  esac

  local activity
  activity=$(activity_for "#${number}")

  local dl_rows="<dt>Repo</dt><dd>$(echo "${repo}" | html_escape)</dd>"
  dl_rows+="<dt>PR</dt><dd><a href=\"${url}\" target=\"_blank\">#${number}</a></dd>"
  [[ "${pending}" -gt 0 ]] && dl_rows+="<dt>Pending</dt><dd>${pending} new comments</dd>"
  [[ -n "${draft_path}" && "${draft_path}" != "null" ]] && dl_rows+="<dt>Drafts</dt><dd><a href=\"/draft/pr-${number}/summary.md\" target=\"_blank\">view drafts →</a></dd>"

  # CI details in expanded card
  if [[ "${ci_total}" -gt 0 ]]; then
    dl_rows+="<dt>CI</dt><dd>${ci_pass} pass"
    [[ "${ci_fail}" -gt 0 ]] && dl_rows+=", <span style=\"color:var(--danger)\">${ci_fail} fail</span>"
    [[ "${ci_pending}" -gt 0 ]] && dl_rows+=", <span style=\"color:var(--warning)\">${ci_pending} pending</span>"
    dl_rows+=" / ${ci_total}</dd>"
    # Link to buildkite if present
    local bk_link
    bk_link=$(echo "${item}" | jq -r '.ci.buildkite.link // ""')
    if [[ -n "${bk_link}" && "${bk_link}" != "null" ]]; then
      dl_rows+="<dt>Buildkite</dt><dd><a href=\"${bk_link}\" target=\"_blank\">view build →</a></dd>"
    fi
    # List failing checks
    local failing_list
    failing_list=$(echo "${item}" | jq -r '.ci.failing // [] | .[] | "<a href=\"\(.link)\" target=\"_blank\">\(.name)</a>"' | tr '\n' ',' | sed 's/,$//; s/,/, /g')
    if [[ -n "${failing_list}" ]]; then
      dl_rows+="<dt>Failing</dt><dd>${failing_list}</dd>"
    fi
  fi

  local esc_title
  esc_title=$(echo "${title}" | html_escape)
  cat <<EOF
<div class="card" title="#${number}: ${esc_title}">
  <div class="card-header">
    <div class="card-title"><span class="caret">▸</span> #${number}</div>
    <div class="card-subtitle" title="${esc_title}">${esc_title}</div>
    <div class="card-badges">${status_badge}${extra_badges}</div>
  </div>
  <div class="card-body">
    <dl>${dl_rows}</dl>
    <div class="activity">
      <h4>Activity</h4>
      ${activity:-<div class=\"entry\">no activity yet</div>}
    </div>
  </div>
</div>
EOF
}

# ---- Load state ----
if [[ ! -f "${QUEUE_FILE}" ]]; then
  echo "ERROR: queue.json not found" >&2
  exit 1
fi
QUEUE=$(cat "${QUEUE_FILE}")

# ---- Build card sections ----
build_ticket_column() {
  local status_filter="$1" badge_class="$2" badge_label="$3"
  local items
  items=$(echo "${QUEUE}" | jq -c --arg s "${status_filter}" '.tickets[]? | select(.status == $s)')
  if [[ -z "${items}" ]]; then
    echo '<div class="empty-state">empty</div>'
    return
  fi
  echo "${items}" | while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    render_ticket_card "${item}" "<span class=\"badge ${badge_class}\">${badge_label}</span>"
  done
}

CARDS_QUEUE=$(build_ticket_column "new" "new" "NEW")

# Approval column combines 3 statuses
CARDS_APPROVAL=""
for st in "ready" "needs-clarification" "awaiting-approval"; do
  items=$(echo "${QUEUE}" | jq -c --arg s "${st}" '.tickets[]? | select(.status == $s)')
  [[ -z "${items}" ]] && continue
  upper=$(echo "${st}" | tr 'a-z-' 'A-Z ')
  while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    CARDS_APPROVAL+=$(render_ticket_card "${item}" "<span class=\"badge ${st}\">${upper}</span>")
    CARDS_APPROVAL+=$'\n'
  done <<< "${items}"
done
[[ -z "${CARDS_APPROVAL// }" ]] && CARDS_APPROVAL='<div class="empty-state">empty</div>'

CARDS_IN_PROGRESS=$(build_ticket_column "in-progress" "in-progress" "CODING")

# PR feedback column
CARDS_PR_FEEDBACK=""
PR_ITEMS=$(echo "${QUEUE}" | jq -c '.prs[]? | select((.pending_comments // 0) > 0)')
if [[ -n "${PR_ITEMS}" ]]; then
  while IFS= read -r pr; do
    [[ -z "${pr}" ]] && continue
    CARDS_PR_FEEDBACK+=$(render_pr_card "${pr}" "<span class=\"badge comments\">FEEDBACK</span>")
    CARDS_PR_FEEDBACK+=$'\n'
  done <<< "${PR_ITEMS}"
fi
[[ -z "${CARDS_PR_FEEDBACK// }" ]] && CARDS_PR_FEEDBACK='<div class="empty-state">empty</div>'

# Backlog
CARDS_BACKLOG=""
BACKLOG_ITEMS=$(echo "${QUEUE}" | jq -c '.backlog[]?' 2>/dev/null || true)
if [[ -n "${BACKLOG_ITEMS}" ]]; then
  while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    CARDS_BACKLOG+=$(render_ticket_card "${item}" "<span class=\"badge backlog\">BACKLOG</span>")
    CARDS_BACKLOG+=$'\n'
  done <<< "${BACKLOG_ITEMS}"
fi
[[ -z "${CARDS_BACKLOG// }" ]] && CARDS_BACKLOG='<div class="empty-state">backlog empty</div>'

# Completed list
COMPLETED_LIST=""
COMPLETED_ITEMS=$(echo "${QUEUE}" | jq -c '.completed[]?' 2>/dev/null || true)
if [[ -n "${COMPLETED_ITEMS}" ]]; then
  while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    id=$(echo "${item}" | jq -r '.id // .number')
    title=$(echo "${item}" | jq -r '.title')
    url=$(echo "${item}" | jq -r '.url // ""')
    esc_id=$(echo "${id}" | html_escape)
    esc_title=$(echo "${title}" | html_escape | cut -c1-60)
    COMPLETED_LIST+="<div class=\"completed-item\"><span><span class=\"icon\">✓</span>${esc_id} · ${esc_title}</span><a class=\"url\" href=\"${url}\" target=\"_blank\">view →</a></div>"$'\n'
  done <<< "${COMPLETED_ITEMS}"
fi
[[ -z "${COMPLETED_LIST// }" ]] && COMPLETED_LIST='<div class="empty-state">nothing completed yet today</div>'

# Global activity tail — dedup consecutive identical messages, last 20, newest first
ACTIVITY_TAIL=""
if [[ -f "${AUDIT_LOG}" ]]; then
  # Dedup consecutive identical messages (ignore timestamp), then take last 20
  DEDUPED=$(awk '{ msg = substr($0, index($0, $2)); if (msg != prev) { print; prev = msg } }' "${AUDIT_LOG}")
  TAIL_LINES=$(echo "${DEDUPED}" | tail -20)
  # Reverse to show newest first
  REVERSED=$(echo "${TAIL_LINES}" | awk '{a[NR]=$0} END {for(i=NR;i>=1;i--) print a[i]}')
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    ts="${line%% *}"
    rest="${line#* }"
    action="${rest%% *}"
    msg="${rest#* }"
    short_ts="${ts##*T}"; short_ts="${short_ts:0:5}"
    iso="${ts}Z"
    ACTIVITY_TAIL+="<div class=\"entry\"><span class=\"ts\" data-ts=\"${iso}\">${short_ts}</span><span class=\"action\">${action}</span>$(echo "${msg}" | html_escape)</div>"$'\n'
  done <<< "${REVERSED}"
fi
[[ -z "${ACTIVITY_TAIL// }" ]] && ACTIVITY_TAIL='<div class="empty-state">no activity</div>'

# Counts
COUNT_QUEUE=$(echo "${QUEUE}" | jq '[.tickets[]? | select(.status == "new")] | length')
COUNT_APPROVAL=$(echo "${QUEUE}" | jq '[.tickets[]? | select(.status == "ready" or .status == "needs-clarification" or .status == "awaiting-approval")] | length')
COUNT_IN_PROGRESS=$(echo "${QUEUE}" | jq '[.tickets[]? | select(.status == "in-progress")] | length')
COUNT_PR_FEEDBACK=$(echo "${QUEUE}" | jq '[.prs[]? | select((.pending_comments // 0) > 0)] | length')
COUNT_BACKLOG=$(echo "${QUEUE}" | jq '(.backlog // []) | length')
COUNT_COMPLETED=$(echo "${QUEUE}" | jq '(.completed // []) | length')

STATE=$(echo "${QUEUE}" | jq -r '.workflow_state // "stopped"')
STATE_UPPER=$(echo "${STATE}" | tr '[:lower:]' '[:upper:]')
LAST_UPDATED=$(date +"%H:%M:%S %Z")
LAST_UPDATED_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Write block content to temp files to avoid shell escaping issues
TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT
printf '%s' "${CARDS_QUEUE}"       > "${TMPDIR}/queue.html"
printf '%s' "${CARDS_APPROVAL}"    > "${TMPDIR}/approval.html"
printf '%s' "${CARDS_IN_PROGRESS}" > "${TMPDIR}/inprogress.html"
printf '%s' "${CARDS_PR_FEEDBACK}" > "${TMPDIR}/prfeedback.html"
printf '%s' "${CARDS_BACKLOG}"     > "${TMPDIR}/backlog.html"
printf '%s' "${COMPLETED_LIST}"    > "${TMPDIR}/completed.html"
printf '%s' "${ACTIVITY_TAIL}"     > "${TMPDIR}/activity.html"

# Splice into template via python
TMPDIR="${TMPDIR}" \
LAST_UPDATED="${LAST_UPDATED}" \
LAST_UPDATED_ISO="${LAST_UPDATED_ISO}" \
STATE_UPPER="${STATE_UPPER}" \
STATE="${STATE}" \
COUNT_QUEUE="${COUNT_QUEUE}" \
COUNT_APPROVAL="${COUNT_APPROVAL}" \
COUNT_IN_PROGRESS="${COUNT_IN_PROGRESS}" \
COUNT_PR_FEEDBACK="${COUNT_PR_FEEDBACK}" \
COUNT_BACKLOG="${COUNT_BACKLOG}" \
COUNT_COMPLETED="${COUNT_COMPLETED}" \
TEMPLATE="${TEMPLATE}" \
OUTPUT="${OUTPUT}" \
python3 <<'PY'
import os
tpl = open(os.environ["TEMPLATE"]).read()
tmp = os.environ["TMPDIR"]

simple = {
  "__LAST_UPDATED__":     os.environ["LAST_UPDATED"],
  "__LAST_UPDATED_ISO__": os.environ["LAST_UPDATED_ISO"],
  "__STATE__":            os.environ["STATE_UPPER"],
  "__STATE_CLASS__":      os.environ["STATE"],
  "__COUNT_QUEUE__":      os.environ["COUNT_QUEUE"],
  "__COUNT_APPROVAL__":   os.environ["COUNT_APPROVAL"],
  "__COUNT_IN_PROGRESS__": os.environ["COUNT_IN_PROGRESS"],
  "__COUNT_PR_FEEDBACK__": os.environ["COUNT_PR_FEEDBACK"],
  "__COUNT_BACKLOG__":    os.environ["COUNT_BACKLOG"],
  "__COUNT_COMPLETED__":  os.environ["COUNT_COMPLETED"],
  "__PATH__":             os.environ["OUTPUT"],
  "__NEXT_JIRA__":        "—",
  "__NEXT_PR__":          "—",
}
for k, v in simple.items():
    tpl = tpl.replace(k, v)

blocks = {
  "__CARDS_QUEUE__":       "queue.html",
  "__CARDS_APPROVAL__":    "approval.html",
  "__CARDS_IN_PROGRESS__": "inprogress.html",
  "__CARDS_PR_FEEDBACK__": "prfeedback.html",
  "__CARDS_BACKLOG__":     "backlog.html",
  "__COMPLETED_LIST__":    "completed.html",
  "__ACTIVITY_TAIL__":     "activity.html",
}
for placeholder, fname in blocks.items():
    path = os.path.join(tmp, fname)
    if os.path.exists(path):
        tpl = tpl.replace(placeholder, open(path).read())

with open(os.environ["OUTPUT"], "w") as f:
    f.write(tpl)
PY

echo "Dashboard generated: ${OUTPUT}"

# Optional: emit markdown summary for Slack (stdout on second line onward)
if [[ "${1:-}" == "--summary" ]]; then
  cat <<EOF

*🔧 Dev Workflow — ${STATE_UPPER}*

• Queue: ${COUNT_QUEUE}   • Awaiting: ${COUNT_APPROVAL}   • In Progress: ${COUNT_IN_PROGRESS}   • PR Feedback: ${COUNT_PR_FEEDBACK}
• Backlog: ${COUNT_BACKLOG}   • Done today: ${COUNT_COMPLETED}

_Last updated: ${LAST_UPDATED}_
_Dashboard: file://${OUTPUT}_
EOF
fi

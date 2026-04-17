#!/usr/bin/env bash
# Poll GitHub for PRs authored by user across all repos
# - Detects merged/closed PRs (for worktree cleanup)
# - Fetches new comments on open PRs (since last_seen_comment_id per PR)
# Outputs JSON to stdout: {"open_prs": [...], "closed_prs": [...], "new_comments": [...]}
# Usage: poll-prs.sh [--verbose]

set -euo pipefail

WORKFLOW_DIR="${HOME}/.claude/workflow"
QUEUE_FILE="${WORKFLOW_DIR}/queue.json"
AUDIT="${WORKFLOW_DIR}/scripts/audit.sh"

VERBOSE=0
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1

log() {
  if [[ "${VERBOSE}" == "1" ]]; then
    echo "[poll-prs] $*" >&2
  fi
}

# Fetch open PRs across all repos authored by user
log "Fetching open PRs (all repos)..."
OPEN_PRS=$(gh search prs --author=@me --state=open \
  --json number,title,url,updatedAt,repository,isDraft \
  --limit 50 2>/dev/null || echo "[]")

OPEN_COUNT=$(echo "${OPEN_PRS}" | jq 'length')
log "Found ${OPEN_COUNT} open PRs"

# Get PRs currently tracked in queue.json
TRACKED_PRS=$(jq '.prs // []' "${QUEUE_FILE}")

# Detect closed/merged PRs (were tracked, no longer in open list)
OPEN_KEYS=$(echo "${OPEN_PRS}" | jq -r '.[] | "\(.repository.nameWithOwner)#\(.number)"' | sort -u)
OPEN_KEYS_JSON=$(echo "${OPEN_KEYS}" | jq -R . | jq -s .)

CLOSED_PRS=$(echo "${TRACKED_PRS}" | jq --argjson open "${OPEN_KEYS_JSON}" \
  '[.[] | select((.repo + "#" + (.number | tostring)) as $key | ($open | index($key) | not))]')

CLOSED_COUNT=$(echo "${CLOSED_PRS}" | jq 'length')
log "Detected ${CLOSED_COUNT} closed/merged PRs"

# For each closed PR, check final state (merged vs closed-without-merge)
ENRICHED_CLOSED="[]"
if [[ "${CLOSED_COUNT}" -gt 0 ]]; then
  ENRICHED_CLOSED=$(echo "${CLOSED_PRS}" | jq -c '.[]' | while read -r pr; do
    REPO=$(echo "${pr}" | jq -r '.repo')
    NUM=$(echo "${pr}" | jq -r '.number')
    FINAL=$(gh api "repos/${REPO}/pulls/${NUM}" --jq '{state, merged: .merged, merged_at: .merged_at, closed_at: .closed_at}' 2>/dev/null || echo '{"state":"unknown"}')
    echo "${pr}" | jq --argjson final "${FINAL}" '. + $final'
  done | jq -s '.')
fi

# Fetch new comments on each open PR
NEW_COMMENTS="[]"
if [[ "${OPEN_COUNT}" -gt 0 ]]; then
  NEW_COMMENTS=$(echo "${OPEN_PRS}" | jq -c '.[]' | while read -r pr; do
    REPO=$(echo "${pr}" | jq -r '.repository.nameWithOwner')
    NUM=$(echo "${pr}" | jq -r '.number')

    # Lookup last_seen_comment_id from queue
    LAST_SEEN=$(echo "${TRACKED_PRS}" | jq -r --arg repo "${REPO}" --argjson num "${NUM}" \
      '[.[] | select(.repo == $repo and .number == $num)] | .[0].last_seen_comment_id // 0')

    # Fetch review comments (inline on code)
    REVIEW_COMMENTS=$(gh api "repos/${REPO}/pulls/${NUM}/comments" --paginate 2>/dev/null || echo "[]")
    # Fetch issue-level comments (on PR description)
    ISSUE_COMMENTS=$(gh api "repos/${REPO}/issues/${NUM}/comments" --paginate 2>/dev/null || echo "[]")
    # Fetch reviews (approval/request-changes with summary body)
    REVIEWS=$(gh api "repos/${REPO}/pulls/${NUM}/reviews" --paginate 2>/dev/null || echo "[]")

    # Normalize each source + tag type, skip bot users, filter by id > last_seen
    echo "${REVIEW_COMMENTS}" | jq --arg repo "${REPO}" --argjson num "${NUM}" --argjson lastseen "${LAST_SEEN}" '
      [.[] | select(.user.type != "Bot" and .id > $lastseen) | {
        type: "review_comment",
        repo: $repo,
        pr_number: $num,
        id: .id,
        user: .user.login,
        body: .body,
        path: .path,
        line: .line,
        created_at: .created_at,
        url: .html_url
      }]'

    echo "${ISSUE_COMMENTS}" | jq --arg repo "${REPO}" --argjson num "${NUM}" --argjson lastseen "${LAST_SEEN}" '
      [.[] | select(.user.type != "Bot" and (.body | test("(?i)coverage report|generated with claude") | not) and .id > $lastseen) | {
        type: "issue_comment",
        repo: $repo,
        pr_number: $num,
        id: .id,
        user: .user.login,
        body: .body,
        created_at: .created_at,
        url: .html_url
      }]'

    echo "${REVIEWS}" | jq --arg repo "${REPO}" --argjson num "${NUM}" --argjson lastseen "${LAST_SEEN}" '
      [.[] | select(.user.type != "Bot" and (.body // "") != "" and .id > $lastseen) | {
        type: "review",
        repo: $repo,
        pr_number: $num,
        id: .id,
        user: .user.login,
        state: .state,
        body: .body,
        created_at: .submitted_at,
        url: .html_url
      }]'
  done | jq -s 'add // []')
fi

NEW_COMMENT_COUNT=$(echo "${NEW_COMMENTS}" | jq 'length')
log "Found ${NEW_COMMENT_COUNT} new comments across open PRs"

# Audit
if [[ "${CLOSED_COUNT}" -gt 0 ]]; then
  "${AUDIT}" "POLL:PR" "detected ${CLOSED_COUNT} closed PRs"
fi
if [[ "${NEW_COMMENT_COUNT}" -gt 0 ]]; then
  "${AUDIT}" "POLL:PR" "found ${NEW_COMMENT_COUNT} new comments"
fi
if [[ "${CLOSED_COUNT}" -eq 0 && "${NEW_COMMENT_COUNT}" -eq 0 ]]; then
  "${AUDIT}" "POLL:PR" "no changes"
fi

# Normalize open_prs + enrich with CI status
CHECK_CI="${WORKFLOW_DIR}/scripts/check-ci.sh"
OPEN_NORMALIZED=$(echo "${OPEN_PRS}" | jq -c '.[]' | while read -r pr; do
  REPO=$(echo "${pr}" | jq -r '.repository.nameWithOwner')
  NUM=$(echo "${pr}" | jq -r '.number')
  CI=$("${CHECK_CI}" "${REPO}" "${NUM}" 2>/dev/null || echo '{"status":"unknown","total":0,"pass":0,"fail":0,"pending":0,"failing":[],"buildkite":null}')
  echo "${pr}" | jq --argjson ci "${CI}" '{
    repo: .repository.nameWithOwner,
    number: .number,
    title: .title,
    url: .url,
    is_draft: .isDraft,
    updated_at: .updatedAt,
    ci: $ci
  }'
done | jq -s '.')

jq -n --argjson open "${OPEN_NORMALIZED}" --argjson closed "${ENRICHED_CLOSED}" --argjson comments "${NEW_COMMENTS}" \
  '{open_prs: $open, closed_prs: $closed, new_comments: $comments}'

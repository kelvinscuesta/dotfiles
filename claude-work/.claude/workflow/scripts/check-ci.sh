#!/usr/bin/env bash
# Check CI status for a PR via gh pr checks
# Usage: check-ci.sh <repo> <pr-number> [--verbose]
# Outputs JSON: {status, pass_count, fail_count, pending_count, skipping_count, total, failing: [{name, link}], buildkite: {name, state, link}}

set -euo pipefail

REPO="${1:?Usage: check-ci.sh <repo> <pr-number>}"
NUM="${2:?Usage: check-ci.sh <repo> <pr-number>}"

CHECKS=$(gh pr checks "${NUM}" --repo "${REPO}" --json name,bucket,state,link 2>/dev/null || echo "[]")

# Count by bucket
PASS=$(echo "${CHECKS}" | jq '[.[] | select(.bucket == "pass")] | length')
FAIL=$(echo "${CHECKS}" | jq '[.[] | select(.bucket == "fail" or .bucket == "cancel")] | length')
PENDING=$(echo "${CHECKS}" | jq '[.[] | select(.bucket == "pending")] | length')
SKIPPING=$(echo "${CHECKS}" | jq '[.[] | select(.bucket == "skipping")] | length')
TOTAL=$(echo "${CHECKS}" | jq 'length')

# Overall status: fail > pending > pass
if [[ "${FAIL}" -gt 0 ]]; then
  STATUS="fail"
elif [[ "${PENDING}" -gt 0 ]]; then
  STATUS="pending"
elif [[ "${TOTAL}" -eq 0 ]]; then
  STATUS="none"
else
  STATUS="pass"
fi

# Failing checks with links
FAILING=$(echo "${CHECKS}" | jq '[.[] | select(.bucket == "fail" or .bucket == "cancel") | {name, link, state}]')

# Pending checks
PENDING_LIST=$(echo "${CHECKS}" | jq '[.[] | select(.bucket == "pending") | {name, link}]')

# Buildkite-specific (primary CI at Gusto)
BUILDKITE=$(echo "${CHECKS}" | jq 'first(.[] | select(.name | startswith("buildkite/") or test("buildkite"; "i"))) // null')

jq -n \
  --arg status "${STATUS}" \
  --argjson pass "${PASS}" \
  --argjson fail "${FAIL}" \
  --argjson pending "${PENDING}" \
  --argjson skipping "${SKIPPING}" \
  --argjson total "${TOTAL}" \
  --argjson failing "${FAILING}" \
  --argjson pending_list "${PENDING_LIST}" \
  --argjson buildkite "${BUILDKITE}" \
  '{status: $status, total: $total, pass: $pass, fail: $fail, pending: $pending, skipping: $skipping, failing: $failing, pending_list: $pending_list, buildkite: $buildkite}'

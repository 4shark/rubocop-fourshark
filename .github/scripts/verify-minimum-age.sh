#!/usr/bin/env bash
# Verify every SHA-pinned GitHub Action used in this repository references
# an upstream commit older than MIN_AGE_DAYS. Posts a "Verify Minimum Age"
# commit status on the target commit, and when all pins clear the cooldown,
# adds a ready-to-merge label and notifies the team.
#
# This fills the gap Renovate's minimumReleaseAge cannot cover for
# GitHub Actions digest updates against moving tags (see Renovate
# discussion #39781), while aligning the visual signal (yellow pending,
# green success) with Renovate's own stability-days check.
#
# State semantics (consistent with Renovate stability-days):
#   pending — at least one pin under MIN_AGE_DAYS; merge blocked
#   success — all pins at or above MIN_AGE_DAYS; merge unblocked
#   error   — could not resolve or parse an upstream commit date
#
# Required env: GH_TOKEN, GITHUB_REPOSITORY, COMMIT_SHA, PR_NUMBER, NOTIFY_HANDLE,
#               MIN_AGE_DAYS
# Optional env: READY_LABEL (default ready-to-merge)
#
# MIN_AGE_DAYS has no default on purpose: a default here is a second place the
# organization-wide policy is written down, and it keeps its own number in
# silence when the organization variable moves.
#
# NOTIFY_HANDLE is the user or team to @-mention when the cooldown clears.
# Team format: <org>/<team-slug>, e.g. 4shark/app-back-end-development.

set -euo pipefail

READY_LABEL="${READY_LABEL:-ready-to-merge}"
STATUS_CONTEXT="Verify Minimum Age"

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${COMMIT_SHA:?COMMIT_SHA is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${NOTIFY_HANDLE:?NOTIFY_HANDLE is required}"
: "${MIN_AGE_DAYS:?DEPENDENCY_MINIMUM_RELEASE_AGE_DAYS is required}"

# Skip verification when the PR diff touches no GHA workflow or composite
# action file. Without GHA pin changes there is nothing to age-verify and the
# "cooldown complete" notification has no semantic meaning. Post a green
# status so branch protection stays satisfied, then bail.
PR_FILES=$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files" --paginate --jq '.[].filename')
if ! echo "$PR_FILES" | grep -qE '^\.github/(workflows|actions)/'; then
  gh api -X POST "repos/${GITHUB_REPOSITORY}/statuses/${COMMIT_SHA}" \
    -f state="success" \
    -f context="$STATUS_CONTEXT" \
    -f description="No GitHub Action pin changes in this PR" >/dev/null
  echo "PR #${PR_NUMBER} touched no .github/workflows or .github/actions file; skipping verification."
  exit 0
fi

NOW=$(date -u +%s)
THRESHOLD_SECONDS=$((MIN_AGE_DAYS * 86400))

WORKFLOWS_DIR=".github/workflows"
ACTIONS_DIR=".github/actions"

STATE=""
DESCRIPTION=""

if [[ ! -d "$WORKFLOWS_DIR" && ! -d "$ACTIONS_DIR" ]]; then
  STATE="success"
  DESCRIPTION="No workflow or action files to verify"
else
  PINS=$(grep -rhE "^[[:space:]]*-?[[:space:]]*uses:[[:space:]]+[^.\/][^@[:space:]]+@[0-9a-f]{40}" \
           "$WORKFLOWS_DIR" "$ACTIONS_DIR" 2>/dev/null \
         | sed -E 's/.*uses:[[:space:]]+([^@[:space:]]+)@([0-9a-f]{40}).*/\1@\2/' \
         | sort -u || true)

  if [[ -z "$PINS" ]]; then
    STATE="success"
    DESCRIPTION="No SHA-pinned GitHub Actions found"
  else
    TOTAL=0
    VIOLATIONS=0
    ERRORS=0
    MIN_AGE_FOUND=999999

    while IFS='@' read -r ACTION SHA; do
      [[ -z "$ACTION" || -z "$SHA" ]] && continue
      TOTAL=$((TOTAL + 1))

      COMMIT_DATE=$(gh api "repos/${ACTION}/commits/${SHA}" --jq '.commit.committer.date' 2>/dev/null || true)
      if [[ -z "$COMMIT_DATE" ]]; then
        echo "::error::${ACTION}@${SHA} — could not resolve upstream commit date"
        ERRORS=$((ERRORS + 1))
        continue
      fi

      COMMIT_TS=$(date -u -d "$COMMIT_DATE" +%s 2>/dev/null || true)
      if [[ -z "$COMMIT_TS" ]]; then
        echo "::error::${ACTION}@${SHA} — could not parse commit date ${COMMIT_DATE}"
        ERRORS=$((ERRORS + 1))
        continue
      fi

      AGE_SECONDS=$((NOW - COMMIT_TS))
      AGE_DAYS=$((AGE_SECONDS / 86400))

      if [[ "$AGE_DAYS" -lt "$MIN_AGE_FOUND" ]]; then
        MIN_AGE_FOUND=$AGE_DAYS
      fi

      if [[ "$AGE_SECONDS" -lt "$THRESHOLD_SECONDS" ]]; then
        echo "::warning::${ACTION}@${SHA} — ${AGE_DAYS} days old (committed ${COMMIT_DATE}); minimum is ${MIN_AGE_DAYS} days"
        VIOLATIONS=$((VIOLATIONS + 1))
      fi
    done <<< "$PINS"

    if [[ "$ERRORS" -gt 0 ]]; then
      STATE="error"
      DESCRIPTION="${ERRORS} pin(s) failed to resolve upstream commit date"
    elif [[ "$VIOLATIONS" -gt 0 ]]; then
      STATE="pending"
      DESCRIPTION="${VIOLATIONS}/${TOTAL} pin(s) under ${MIN_AGE_DAYS}-day cooldown; youngest is ${MIN_AGE_FOUND} days old"
    else
      STATE="success"
      DESCRIPTION="All ${TOTAL} SHA-pinned action(s) at or above ${MIN_AGE_DAYS} days"
    fi
  fi
fi

gh api -X POST "repos/${GITHUB_REPOSITORY}/statuses/${COMMIT_SHA}" \
  -f state="$STATE" \
  -f context="$STATUS_CONTEXT" \
  -f description="${DESCRIPTION:0:140}" >/dev/null
echo "Posted commit status: state=${STATE} description=${DESCRIPTION}"

HAS_LABEL=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/labels" --jq ".[].name" | grep -Fxq "$READY_LABEL" && echo "yes" || echo "no")

if [[ "$STATE" == "success" && "$HAS_LABEL" == "no" ]]; then
  if ! gh api "repos/${GITHUB_REPOSITORY}/labels/${READY_LABEL}" >/dev/null 2>&1; then
    gh api -X POST "repos/${GITHUB_REPOSITORY}/labels" \
      -f name="$READY_LABEL" \
      -f color="0e8a16" \
      -f description="Renovate cooldown complete — safe to merge" >/dev/null
  fi
  gh api -X POST "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/labels" \
    -f "labels[]=${READY_LABEL}" >/dev/null
  gh api -X POST "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
    -f body="@${NOTIFY_HANDLE} cooldown of ${MIN_AGE_DAYS}+ days complete — this PR is now mergeable." >/dev/null
  echo "Added label '${READY_LABEL}' and notified @${NOTIFY_HANDLE} on PR #${PR_NUMBER}."
elif [[ "$STATE" != "success" && "$HAS_LABEL" == "yes" ]]; then
  gh api -X DELETE "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/labels/${READY_LABEL}" >/dev/null
  echo "Removed label '${READY_LABEL}' from PR #${PR_NUMBER} (cooldown restarted)."
fi

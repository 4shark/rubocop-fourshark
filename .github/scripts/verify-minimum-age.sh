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

# Skip verification when the PR diff moves no dependency this script can age.
# Without such a change there is nothing to verify and the "cooldown complete"
# notification has no semantic meaning. Post a green status so branch
# protection stays satisfied, then bail.
PR_FILES=$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files" --paginate --jq '.[].filename')
if ! echo "$PR_FILES" | grep -qE '^(\.github/(workflows|actions)/|Gemfile\.lock$)'; then
  gh api -X POST "repos/${GITHUB_REPOSITORY}/statuses/${COMMIT_SHA}" \
    -f state="success" \
    -f context="$STATUS_CONTEXT" \
    -f description="No dependency pin or lockfile changes in this PR" >/dev/null
  echo "PR #${PR_NUMBER} touched no .github/workflows, .github/actions or Gemfile.lock file; skipping verification."
  exit 0
fi

NOW=$(date -u +%s)
THRESHOLD_SECONDS=$((MIN_AGE_DAYS * 86400))

WORKFLOWS_DIR=".github/workflows"
ACTIONS_DIR=".github/actions"

TOTAL=0
VIOLATIONS=0
ERRORS=0
MIN_AGE_FOUND=999999

if [[ -d "$WORKFLOWS_DIR" || -d "$ACTIONS_DIR" ]]; then
  PINS=$(grep -rhE "^[[:space:]]*-?[[:space:]]*uses:[[:space:]]+[^.\/][^@[:space:]]+@[0-9a-f]{40}" \
           "$WORKFLOWS_DIR" "$ACTIONS_DIR" 2>/dev/null \
         | sed -E 's/.*uses:[[:space:]]+([^@[:space:]]+)@([0-9a-f]{40}).*/\1@\2/' \
         | sort -u || true)

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
fi

# Only the gems this PR actually moves are aged, so the check answers for the
# diff rather than for the whole lockfile — a gem that has sat at its version
# for a year is not re-verified on every unrelated pull request. A four-space
# indent is a spec line; CHECKSUMS entries carry two and never match.
LOCKFILE_PATCH=$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files" --paginate \
                   --jq '.[] | select(.filename == "Gemfile.lock") | .patch' 2>/dev/null || true)
GEMS=$(echo "$LOCKFILE_PATCH" \
       | grep -E '^\+    [a-zA-Z0-9._-]+ \([0-9][^)]*\)$' \
       | sed -E 's/^\+    ([a-zA-Z0-9._-]+) \(([^)]+)\)$/\1@\2/' \
       | sort -u || true)

while IFS='@' read -r GEM VERSION; do
  [[ -z "$GEM" || -z "$VERSION" ]] && continue
  TOTAL=$((TOTAL + 1))

  # A hyphen in a lockfile version is always a platform suffix — RubyGems
  # spells prereleases with a dot — and the release endpoint takes the bare
  # version.
  RELEASE_VERSION="${VERSION%%-*}"

  # built_at is unreliable on RubyGems (some releases carry 1980); created_at
  # is when the version was actually published.
  RELEASE_DATE=$(curl -sf "https://rubygems.org/api/v2/rubygems/${GEM}/versions/${RELEASE_VERSION}.json" \
                 | jq -r '.created_at // empty' 2>/dev/null || true)
  if [[ -z "$RELEASE_DATE" ]]; then
    echo "::error::${GEM} ${VERSION} — could not resolve RubyGems release date"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  RELEASE_TS=$(date -u -d "$RELEASE_DATE" +%s 2>/dev/null || true)
  if [[ -z "$RELEASE_TS" ]]; then
    echo "::error::${GEM} ${VERSION} — could not parse release date ${RELEASE_DATE}"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  AGE_SECONDS=$((NOW - RELEASE_TS))
  AGE_DAYS=$((AGE_SECONDS / 86400))

  if [[ "$AGE_DAYS" -lt "$MIN_AGE_FOUND" ]]; then
    MIN_AGE_FOUND=$AGE_DAYS
  fi

  if [[ "$AGE_SECONDS" -lt "$THRESHOLD_SECONDS" ]]; then
    echo "::warning::${GEM} ${VERSION} — ${AGE_DAYS} days old (released ${RELEASE_DATE}); minimum is ${MIN_AGE_DAYS} days"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done <<< "$GEMS"

STATE=""
DESCRIPTION=""

if [[ "$ERRORS" -gt 0 ]]; then
  STATE="error"
  DESCRIPTION="${ERRORS} dependency/dependencies failed to resolve a release date"
elif [[ "$TOTAL" -eq 0 ]]; then
  STATE="success"
  DESCRIPTION="No SHA-pinned actions or moved gems to verify"
elif [[ "$VIOLATIONS" -gt 0 ]]; then
  STATE="pending"
  DESCRIPTION="${VIOLATIONS}/${TOTAL} dependency/dependencies under ${MIN_AGE_DAYS}-day cooldown; youngest is ${MIN_AGE_FOUND} days old"
else
  STATE="success"
  DESCRIPTION="All ${TOTAL} dependency/dependencies at or above ${MIN_AGE_DAYS} days"
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

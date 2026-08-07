#!/usr/bin/env bash
# Publish the result of a `bundle update` run as a pull request.
#
# Renovate updates the dependencies declared in the Gemfile; the ones those
# dependencies pull in transitively only move when a declared dependency drags
# them along. This script carries the rest: the weekly workflow re-resolves the
# whole lockfile and this turns the resulting diff into a reviewable PR.
#
# The branch name is fixed, so a run whose diff differs from the open PR updates
# that PR in place instead of stacking a new one every week.
#
# The age gate lives in the `bundle update` step, not here: BUNDLE_COOLDOWN makes
# Bundler refuse any version published within the cooldown window, across the
# whole resolution — transitive dependencies included.
#
# Required env: GH_TOKEN, GITHUB_REPOSITORY, GITHUB_REF_NAME

set -euo pipefail

BRANCH_NAME="chore/bundle-update"
COMMIT_SUBJECT="chore(deps): update the resolved dependency versions"
BOT_NAME="github-actions[bot]"
BOT_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_REF_NAME:?GITHUB_REF_NAME is required}"

if git diff --quiet -- Gemfile.lock; then
  echo "Gemfile.lock is unchanged; every resolved version is already current."
  exit 0
fi

BASE_BRANCH="$GITHUB_REF_NAME"

git config user.name "$BOT_NAME"
git config user.email "$BOT_EMAIL"

git checkout -b "$BRANCH_NAME"
git add Gemfile.lock
git commit -m "$COMMIT_SUBJECT"
git push --force origin "${BRANCH_NAME}:refs/heads/${BRANCH_NAME}"

OPEN_PULL_REQUEST=$(gh pr list --repo "$GITHUB_REPOSITORY" --head "$BRANCH_NAME" --state open --json number --jq '.[0].number')

if [[ -n "$OPEN_PULL_REQUEST" ]]; then
  echo "Updated the branch behind pull request #${OPEN_PULL_REQUEST}."
  exit 0
fi

gh pr create \
  --repo "$GITHUB_REPOSITORY" \
  --base "$BASE_BRANCH" \
  --head "$BRANCH_NAME" \
  --title "$COMMIT_SUBJECT" \
  --body "Re-resolved every version in \`Gemfile.lock\`, including the dependencies pulled in transitively, which Renovate leaves untouched.

No version in this diff was published within the minimum release age — Bundler's own cooldown enforces that during resolution, so the age gate covers transitive dependencies as well.

The diff is limited to \`Gemfile.lock\`; nothing declared in the \`Gemfile\` changed."

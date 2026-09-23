#!/usr/bin/env bash
# Verify that every dependency version this pull request introduces was
# published at least MIN_AGE_DAYS ago. Posts a "Verify Minimum Age" commit
# status on the target commit, and when everything clears the cooldown, adds a
# ready-to-merge label and notifies the team.
#
# Renovate's minimumReleaseAge ages only the dependency it updates. This covers
# what it cannot see: SHA-pinned GitHub Actions against moving tags (Renovate
# discussion #39781), and every version a resolver writes into a lockfile
# beyond the declared one — the transitive dependencies.
#
#   GitHub Actions  every SHA pin under .github/workflows and .github/actions
#   RubyGems        Gemfile.lock, GEM section only (PATH and GIT have no release)
#   npm             yarn.lock, Yarn Classic and Berry, registry entries only
#   pub.dev         pubspec.lock, hosted packages only
#   PyPI            requirements*.txt, exact == pins
#   NuGet           *.csproj and Directory.Packages.props, exact versions
#
# A manifest or lockfile is compared between the merge base and the head, so
# only the versions this pull request adds are aged — a dependency that has
# sat at its version for a year is not re-verified on every unrelated PR.
#
# State semantics (consistent with Renovate stability-days):
#   pending — at least one version under MIN_AGE_DAYS; merge blocked
#   success — every version at or above MIN_AGE_DAYS; merge unblocked
#   error   — could not read a file or resolve a release date
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

export LC_ALL=C

READY_LABEL="${READY_LABEL:-ready-to-merge}"
STATUS_CONTEXT="Verify Minimum Age"
DEPENDENCY_FILE_PATTERN='^(\.github/(workflows|actions)/|(.*/)?(Gemfile\.lock|yarn\.lock|pubspec\.lock|requirements[^/]*\.txt|[^/]+\.csproj|Directory\.Packages\.props)$)'

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${COMMIT_SHA:?COMMIT_SHA is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${NOTIFY_HANDLE:?NOTIFY_HANDLE is required}"
: "${MIN_AGE_DAYS:?DEPENDENCY_MINIMUM_RELEASE_AGE_DAYS is required}"

# Prints one "name<TAB>version" line per registry release the file pins.
list_versions() {
  local ecosystem="$1"
  local file="$2"

  case "$ecosystem" in
    rubygems)
      awk '
        /^[A-Z]/ { in_gem_section = ($0 == "GEM") }
        in_gem_section && /^    [a-zA-Z0-9._-]+ \([0-9][^)]*\)$/ { version = $2; gsub(/[()]/, "", version); print $1 "\t" version }
      ' "$file"
      ;;
    npm)
      sed -nE \
        -e 's/^  resolution: "(.+)@npm:([^"]+)"$/\1\t\2/p' \
        -e 's%^  resolved "https://registry\.(yarnpkg\.com|npmjs\.org)/((@[^/]+/)?([^/]+))/-/\4-([^"#]+)\.tgz(#[^"]*)?"$%\2\t\5%p' \
        "$file"
      ;;
    pub)
      awk '
        /^  [^ ]/ { package_name = ""; package_source = "" }
        /^      name: / { package_name = $2 }
        /^    source: / { package_source = $2 }
        /^    version: / && package_source == "hosted" { version = $2; gsub(/"/, "", version); print package_name "\t" version }
      ' "$file"
      ;;
    pypi)
      sed -nE 's/^([A-Za-z0-9][A-Za-z0-9._-]*)(\[[^]]*\])?[[:space:]]*==[[:space:]]*([^[:space:];#]+).*$/\1\t\3/p' "$file"
      ;;
    nuget)
      sed -nE \
        -e 's/.*<Package(Reference|Version)[[:space:]]+Include="([^"]+)"[[:space:]]+Version="([0-9][^"*,()$]*)".*/\2\t\3/p' \
        -e 's/.*<Package(Reference|Version)[[:space:]]+Version="([0-9][^"*,()$]*)"[[:space:]]+Include="([^"]+)".*/\3\t\2/p' \
        "$file"
      ;;
  esac
}

# --paginate prints the pages it fetched before failing on a later one, so only the
# exit status tells a truncated list from a complete one.
if ! PR_FILES=$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files" --paginate \
                  --jq '.[] | "\(.status)\t\(.filename)\t\(.previous_filename // .filename)"' 2>/dev/null); then
  PR_FILES=""
fi

# A pull request always changes at least one file, so an empty list means the read failed.
if [[ -z "$PR_FILES" ]]; then
  gh api -X POST "repos/${GITHUB_REPOSITORY}/statuses/${COMMIT_SHA}" \
    -f state="error" \
    -f context="$STATUS_CONTEXT" \
    -f description="Could not read the pull request file list" >/dev/null
  echo "::error::could not read the file list of PR #${PR_NUMBER}"
  exit 0
fi

# Skip verification when the PR diff moves no dependency this script can age.
# Without such a change there is nothing to verify and the "cooldown complete"
# notification has no semantic meaning. Post a green status so branch
# protection stays satisfied, then bail.
PR_PATHS=$(printf '%s\n' "$PR_FILES" | cut -f2)
if ! grep -qE "$DEPENDENCY_FILE_PATTERN" <<< "$PR_PATHS"; then
  gh api -X POST "repos/${GITHUB_REPOSITORY}/statuses/${COMMIT_SHA}" \
    -f state="success" \
    -f context="$STATUS_CONTEXT" \
    -f description="No dependency pin, manifest or lockfile changes in this PR" >/dev/null
  echo "PR #${PR_NUMBER} touched no workflow, action, manifest or lockfile; skipping verification."
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
DEPENDENCIES=""

if [[ -d "$WORKFLOWS_DIR" || -d "$ACTIONS_DIR" ]]; then
  PINS=$(grep -rhE "^[[:space:]]*-?[[:space:]]*uses:[[:space:]]+[^.\/][^@[:space:]]+@[0-9a-f]{40}" \
           "$WORKFLOWS_DIR" "$ACTIONS_DIR" 2>/dev/null \
         | sed -E 's/.*uses:[[:space:]]+([^@[:space:]]+)@([0-9a-f]{40}).*/\1@\2/' \
         | sort -u || true)

  while IFS='@' read -r ACTION SHA; do
    [[ -z "$ACTION" || -z "$SHA" ]] && continue
    DEPENDENCIES+="action"$'\t'"${ACTION}"$'\t'"${SHA}"$'\n'
  done <<< "$PINS"
fi

BASE_REF=$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}" --jq '.base.ref' 2>/dev/null || true)
MERGE_BASE_SHA=$(gh api "repos/${GITHUB_REPOSITORY}/compare/${BASE_REF}...${COMMIT_SHA}" --jq '.merge_base_commit.sha // empty' 2>/dev/null || true)

# An empty ref makes the contents API answer from the default branch instead of failing.
if [[ -z "$MERGE_BASE_SHA" ]]; then
  echo "::error::could not resolve the merge base of ${COMMIT_SHA}"
  ERRORS=$((ERRORS + 1))
fi

HEAD_CONTENT_FILE=$(mktemp)
BASE_CONTENT_FILE=$(mktemp)
trap 'rm -f "$HEAD_CONTENT_FILE" "$BASE_CONTENT_FILE"' EXIT

while IFS=$'\t' read -r FILE_STATUS FILE_PATH PREVIOUS_PATH; do
  [[ -z "$FILE_PATH" || "$FILE_STATUS" == "removed" ]] && continue

  case "$FILE_PATH" in
    Gemfile.lock | */Gemfile.lock) ECOSYSTEM="rubygems" ;;
    yarn.lock | */yarn.lock) ECOSYSTEM="npm" ;;
    pubspec.lock | */pubspec.lock) ECOSYSTEM="pub" ;;
    requirements*.txt | */requirements*.txt) ECOSYSTEM="pypi" ;;
    *.csproj | Directory.Packages.props | */Directory.Packages.props) ECOSYSTEM="nuget" ;;
    *) continue ;;
  esac

  if ! gh api -H "Accept: application/vnd.github.raw" "repos/${GITHUB_REPOSITORY}/contents/${FILE_PATH}?ref=${COMMIT_SHA}" > "$HEAD_CONTENT_FILE" 2>/dev/null; then
    echo "::error::${FILE_PATH} — could not read the file at ${COMMIT_SHA}"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  : > "$BASE_CONTENT_FILE"

  if [[ "$FILE_STATUS" != "added" && -z "$MERGE_BASE_SHA" ]]; then
    continue
  fi

  if [[ "$FILE_STATUS" != "added" ]] && ! gh api -H "Accept: application/vnd.github.raw" "repos/${GITHUB_REPOSITORY}/contents/${PREVIOUS_PATH}?ref=${MERGE_BASE_SHA}" > "$BASE_CONTENT_FILE" 2>/dev/null; then
    echo "::error::${PREVIOUS_PATH} — could not read the file at ${MERGE_BASE_SHA}"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  ADDED_VERSIONS=$(comm -13 <(list_versions "$ECOSYSTEM" "$BASE_CONTENT_FILE" | sort -u) <(list_versions "$ECOSYSTEM" "$HEAD_CONTENT_FILE" | sort -u))

  while IFS=$'\t' read -r PACKAGE VERSION; do
    [[ -z "$PACKAGE" || -z "$VERSION" ]] && continue
    DEPENDENCIES+="${ECOSYSTEM}"$'\t'"${PACKAGE}"$'\t'"${VERSION}"$'\n'
  done <<< "$ADDED_VERSIONS"
done <<< "$PR_FILES"

UNIQUE_DEPENDENCIES=$(printf '%s' "$DEPENDENCIES" | sort -u)

while IFS=$'\t' read -r ECOSYSTEM PACKAGE VERSION; do
  [[ -z "$ECOSYSTEM" ]] && continue
  TOTAL=$((TOTAL + 1))

  case "$ECOSYSTEM" in
    action)
      RELEASE_DATE=$(gh api "repos/${PACKAGE}/commits/${VERSION}" --jq '.commit.committer.date' 2>/dev/null || true)
      ;;
    rubygems)
      # A hyphen in a lockfile version is always a platform suffix — RubyGems
      # spells prereleases with a dot — and the release endpoint takes the bare
      # version. built_at is unreliable (some releases carry 1980); created_at
      # is when the version was actually published.
      RELEASE_DATE=$(curl -sf "https://rubygems.org/api/v2/rubygems/${PACKAGE}/versions/${VERSION%%-*}.json" \
                     | jq -r '.created_at // empty' 2>/dev/null || true)
      ;;
    npm)
      RELEASE_DATE=$(curl -sf "https://registry.npmjs.org/${PACKAGE/\//%2F}" \
                     | jq -r --arg version "$VERSION" '.time[$version] // empty' 2>/dev/null || true)
      ;;
    pub)
      RELEASE_DATE=$(curl -sf "https://pub.dev/api/packages/${PACKAGE}/versions/${VERSION}" \
                     | jq -r '.published // empty' 2>/dev/null || true)
      ;;
    pypi)
      RELEASE_DATE=$(curl -sfL "https://pypi.org/pypi/${PACKAGE}/${VERSION}/json" \
                     | jq -r '[.urls[].upload_time_iso_8601] | min // empty' 2>/dev/null || true)
      ;;
    nuget)
      NUGET_PATH=$(echo "${PACKAGE}/${VERSION}" | tr '[:upper:]' '[:lower:]')
      RELEASE_DATE=$(curl -sf --compressed "https://api.nuget.org/v3/registration5-gz-semver2/${NUGET_PATH}.json" \
                     | jq -r '.published // empty' 2>/dev/null || true)
      ;;
  esac

  if [[ -z "$RELEASE_DATE" ]]; then
    echo "::error::${PACKAGE} ${VERSION} — could not resolve the ${ECOSYSTEM} release date"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  RELEASE_TS=$(date -u -d "$RELEASE_DATE" +%s 2>/dev/null || true)
  if [[ -z "$RELEASE_TS" ]]; then
    echo "::error::${PACKAGE} ${VERSION} — could not parse release date ${RELEASE_DATE}"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  AGE_SECONDS=$((NOW - RELEASE_TS))
  AGE_DAYS=$((AGE_SECONDS / 86400))

  if [[ "$AGE_DAYS" -lt "$MIN_AGE_FOUND" ]]; then
    MIN_AGE_FOUND=$AGE_DAYS
  fi

  if [[ "$AGE_SECONDS" -lt "$THRESHOLD_SECONDS" ]]; then
    echo "::warning::${PACKAGE} ${VERSION} (${ECOSYSTEM}) — ${AGE_DAYS} days old (released ${RELEASE_DATE}); minimum is ${MIN_AGE_DAYS} days"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done <<< "$UNIQUE_DEPENDENCIES"

STATE=""
DESCRIPTION=""

if [[ "$ERRORS" -gt 0 ]]; then
  STATE="error"
  DESCRIPTION="${ERRORS} dependency/dependencies or files failed to resolve"
elif [[ "$TOTAL" -eq 0 ]]; then
  STATE="success"
  DESCRIPTION="No SHA-pinned actions or added dependency versions to verify"
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

#!/usr/bin/env bash
# Re-resolve only the dependencies this repository does not declare.
#
# Renovate opens a pull request for what a manifest declares; the gems those
# declarations drag in never move on their own. This script carries exactly that
# remainder and nothing else: for every lockfile in the repository it works out
# which gems no manifest declares and updates only those. A declared gem keeps
# the version it is locked to, so a direct-dependency bump stays a pull request
# of its own that can be reviewed and reverted on its own terms, instead of
# arriving inside a weekly batch.
#
# `bundle update` has no flag for this. What it does have is the documented
# guarantee that naming gems unlocks those gems and leaves the declared ones
# nobody named at their locked versions, so naming the whole transitive set is
# how "everything except what we declare" is expressed. `--conservative` is
# deliberately absent: it would forbid the resolution from pulling in a gem that
# a newly-updated dependency introduces, which is a legitimate outcome here.
#
# A gem counts as declared when the lockfile's DEPENDENCIES section names it, or
# when a path source in the lockfile depends on it — a gemspec's own runtime
# dependencies reach the lockfile that second way and are every bit as declared
# as a `gem` line in the Gemfile.
#
# The lockfiles are discovered rather than listed, so a bundle added later is
# picked up without editing this script.
#
# BUNDLE_COOLDOWN reaches Bundler through the environment and applies to each
# resolution independently — it is what keeps a version published inside the
# minimum release age out of every lockfile here.
#
# Required env: BUNDLE_COOLDOWN

set -euo pipefail

: "${BUNDLE_COOLDOWN:?BUNDLE_COOLDOWN is required}"

# Prints one gem name per line for `transitive`, or one `name version` pair per
# line for `declared`. Both answers come from a single definition of declared, so
# the update below and the check that follows it can never disagree about what a
# direct dependency is.
lockfile_gems() {
  ruby -rbundler -e '
    parser = Bundler::LockfileParser.new(File.read(ARGV[1]))
    declared = parser.dependencies.keys
    parser.specs.each do |spec|
      declared.concat(spec.dependencies.map(&:name)) if spec.source.is_a?(Bundler::Source::Path)
    end

    case ARGV[0]
    when "transitive"
      puts(parser.specs.map(&:name).uniq.sort - declared)
    when "declared"
      declared_specs = parser.specs.select { |spec| declared.include?(spec.name) }
      puts(declared_specs.map { |spec| "#{spec.name} #{spec.version}" }.uniq.sort)
    end
  ' -- "$1" "$2"
}

while IFS= read -r lockfile; do
  bundle_directory=$(dirname "$lockfile")
  echo "==> Updating the transitive dependencies in ${bundle_directory}"

  transitive_gems=()
  while IFS= read -r gem_name; do
    transitive_gems+=("$gem_name")
  done < <(lockfile_gems transitive "$lockfile")

  if [[ ${#transitive_gems[@]} -eq 0 ]]; then
    echo "    Every gem in this lockfile is declared; there is nothing transitive to update."
    continue
  fi

  echo "    ${#transitive_gems[@]} gems here are transitive; every declared one stays where it is."
  declared_before=$(lockfile_gems declared "$lockfile")

  # Nothing here puts the bundle in deployment mode, but frozen would refuse to
  # write the lockfile this job exists to change, so unset it either way.
  (cd "$bundle_directory" && bundle config set frozen false && bundle update "${transitive_gems[@]}")

  declared_after=$(lockfile_gems declared "$lockfile")

  if [[ "$declared_before" != "$declared_after" ]]; then
    echo "A declared dependency moved in ${lockfile}, which this job must never do:" >&2
    diff <(echo "$declared_before") <(echo "$declared_after") >&2 || true
    exit 1
  fi
done < <(find . -name Gemfile.lock -not -path './vendor/*' -not -path './.git/*' | sort)

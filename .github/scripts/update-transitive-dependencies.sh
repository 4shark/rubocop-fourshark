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
# Bundler has no flag for this. What it does have is the documented guarantee
# that naming gems unlocks those gems and leaves the declared ones nobody named
# at their locked versions, so naming the whole transitive set is how
# "everything except what we declare" is expressed.
#
# Two things stand between that expression and a resolution the guard below will
# accept, and they are different problems:
#
#   `--conservative` closes the first. Naming a gem unlocks its own dependencies
#   too, so updating a transitive gem drags along whatever it depends on —
#   including a gem the repository declares. Conservative resolution holds a
#   shared dependency at its locked version, which is the whole point here.
#
#   The retry loop closes the second, which no flag reaches. A transitive gem's
#   new version can be flatly incompatible with a declared gem's locked version —
#   either it no longer satisfies what the declared gem requires, or it demands a
#   declared gem newer than the one locked. The resolver's only way out is to
#   move the declared gem, and it will, forwards or backwards. So when a declared
#   gem moves, the transitive gems whose requirements left no alternative are
#   held back and the resolution is run again. They stay at their locked versions
#   until Renovate proposes the declared bump that frees them, which is exactly
#   the division of labour this job exists to respect.
#
# `bundle lock` rather than `bundle update` because the lockfile is the entire
# output — installing every gem to produce it costs minutes per attempt and buys
# a retry loop nothing. BUNDLE_COOLDOWN applies to a `bundle lock` resolution
# just as it does to an install, so the minimum release age still refuses any
# version published inside the window.
#
# A gem counts as declared when the lockfile's DEPENDENCIES section names it, or
# when a path source in the lockfile depends on it — a gemspec's own runtime
# dependencies reach the lockfile that second way and are every bit as declared
# as a `gem` line in the Gemfile.
#
# The lockfiles are discovered rather than listed, so a bundle added later is
# picked up without editing this script.
#
# Required env: BUNDLE_COOLDOWN

set -euo pipefail

: "${BUNDLE_COOLDOWN:?BUNDLE_COOLDOWN is required}"

# Every pass can only shrink the candidate set, so the loop terminates on its
# own. The bound turns a resolution that keeps finding new conflicts into a
# failure somebody reads rather than a step that runs until it times out.
MAXIMUM_ATTEMPTS=5

# Prints one gem name per line for `transitive` and `constraining`, or one
# `name version` pair per line for `declared`. Every answer comes from a single
# definition of declared, so the update, the check that follows it and the gems
# held back between attempts can never disagree about what a direct dependency
# is.
#
# `constraining` compares the lockfile as it stood before the resolution against
# the one the resolution produced, and names the transitive gems that left the
# resolver no way to keep a declared gem where it was: a dependency whose
# resolved version no longer satisfies what the moved gem requires, and a gem
# whose resolved version requires the moved gem to be something other than what
# it is locked to. Nothing else is named — a gem that merely sits next to the
# conflict keeps its chance to update.
lockfile_gems() {
  ruby -rbundler -e '
    read_lockfile = lambda do |path|
      parser = Bundler::LockfileParser.new(File.read(path))
      declared = parser.dependencies.keys
      parser.specs.each do |spec|
        declared.concat(spec.dependencies.map(&:name)) if spec.source.is_a?(Bundler::Source::Path)
      end
      [parser, declared]
    end

    parser, declared = read_lockfile.call(ARGV[1])

    case ARGV[0]
    when "transitive"
      puts(parser.specs.map(&:name).uniq.sort - declared)
    when "declared"
      declared_specs = parser.specs.select { |spec| declared.include?(spec.name) }
      puts(declared_specs.map { |spec| "#{spec.name} #{spec.version}" }.uniq.sort)
    when "constraining"
      resolved_parser, = read_lockfile.call(ARGV[2])
      resolved_versions = {}
      resolved_parser.specs.each { |spec| resolved_versions[spec.name] = spec.version }

      moved_specs = parser.specs.select do |spec|
        declared.include?(spec.name) &&
          resolved_versions.key?(spec.name) &&
          resolved_versions[spec.name] != spec.version
      end

      constraining = []
      moved_specs.each do |moved_spec|
        moved_spec.dependencies.each do |dependency|
          resolved_version = resolved_versions[dependency.name]
          next if resolved_version.nil?
          constraining << dependency.name unless dependency.requirement.satisfied_by?(resolved_version)
        end

        resolved_parser.specs.each do |spec|
          spec.dependencies.each do |dependency|
            next unless dependency.name == moved_spec.name
            constraining << spec.name unless dependency.requirement.satisfied_by?(moved_spec.version)
          end
        end
      end

      puts(constraining.uniq.sort)
    end
  ' -- "$1" "$2" "${3:-}"
}

while IFS= read -r lockfile; do
  bundle_directory=$(dirname "$lockfile")
  echo "==> Updating the transitive dependencies in ${bundle_directory}"

  candidate_gems=()
  while IFS= read -r gem_name; do
    candidate_gems+=("$gem_name")
  done < <(lockfile_gems transitive "$lockfile")

  if [[ ${#candidate_gems[@]} -eq 0 ]]; then
    echo "    Every gem in this lockfile is declared; there is nothing transitive to update."
    continue
  fi

  echo "    ${#candidate_gems[@]} gems here are transitive; every declared one stays where it is."

  # Each attempt resolves against the lockfile as it stood at the start, never
  # against the rejected result of the attempt before it.
  locked_lockfile=$(mktemp)
  cp "$lockfile" "$locked_lockfile"
  declared_before=$(lockfile_gems declared "$locked_lockfile")

  # Nothing here puts the bundle in deployment mode, but frozen would refuse to
  # write the lockfile this job exists to change, so unset it either way.
  (cd "$bundle_directory" && bundle config set frozen false)

  attempt=1
  failure=""

  while true; do
    cp "$locked_lockfile" "$lockfile"

    (cd "$bundle_directory" && bundle lock --conservative --update "${candidate_gems[@]}")

    declared_after=$(lockfile_gems declared "$lockfile")

    if [[ "$declared_before" == "$declared_after" ]]; then
      break
    fi

    echo "    Attempt ${attempt} moved a declared dependency:"
    diff <(echo "$declared_before") <(echo "$declared_after") || true

    constraining_gems=$(lockfile_gems constraining "$locked_lockfile" "$lockfile")

    # `comm` gives a wrong answer rather than an error on unsorted input; both
    # sides come out of `lockfile_gems` sorted and stay that way through here.
    remaining_gems=()
    while IFS= read -r gem_name; do
      remaining_gems+=("$gem_name")
    done < <(comm -23 <(printf '%s\n' "${candidate_gems[@]}") <(printf '%s\n' "$constraining_gems"))

    held_back=$((${#candidate_gems[@]} - ${#remaining_gems[@]}))

    if [[ $held_back -eq 0 ]]; then
      failure="no transitive gem explains it"
      break
    fi

    if [[ ${#remaining_gems[@]} -eq 0 ]]; then
      echo "    Every transitive gem here is held back by a declared one; this lockfile cannot move until Renovate bumps a declared dependency."
      cp "$locked_lockfile" "$lockfile"
      break
    fi

    if [[ $attempt -ge $MAXIMUM_ATTEMPTS ]]; then
      failure="the resolution kept finding new conflicts across ${MAXIMUM_ATTEMPTS} attempts"
      break
    fi

    echo "    Holding back ${held_back} transitive gems a declared dependency constrains, and resolving again:"
    printf '%s\n' "$constraining_gems" | sed 's/^/      /'

    candidate_gems=("${remaining_gems[@]}")
    attempt=$((attempt + 1))
  done

  if [[ -n "$failure" ]]; then
    echo "A declared dependency moved in ${lockfile}, which this job must never do, and ${failure}:" >&2
    diff <(echo "$declared_before") <(echo "$declared_after") >&2 || true
    cp "$locked_lockfile" "$lockfile"
    rm -f "$locked_lockfile"
    exit 1
  fi

  rm -f "$locked_lockfile"
done < <(find . -name Gemfile.lock -not -path './vendor/*' -not -path './.git/*' | sort)

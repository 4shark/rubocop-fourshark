## [Unreleased]

### Added

- `Layout/EmptyLineBeforeGuardClause` — a guard clause that follows ordinary code must be preceded by a blank line
- Automated dependency-update runs
- Minimum-age verification on pull requests, re-evaluated daily

### Fixed

- Weekly transitive dependency updates
- Transitive dependency pull request now covers every lockfile the update touched
- Lockfile discovery no longer publishes a short set when the search itself fails
- Transitive resolution no longer runs on a short lockfile set when the search itself fails
- Lockfile discovery skips the bundles vendored under node_modules
- Held-back gem list pinned to the collation that sorted it
- Daily dependency age re-check leaving pull requests without the status they need to merge
- Dependency age checks running with no configured minimum
- Minimum release age applied to the weekly transitive dependency update
- Ruby setup action pinned like every other action in the workflows

## [0.8.6] - 2026-08-08

### Fixed

- `Style/DisallowDelegate` — a chained receiver carrying an own state argument is no longer flagged

## [0.8.5] - 2026-08-07

### Changed

- Convention rationale in the README

### Fixed

- `Style/DisallowDelegate` — a macro aimed at the object's own class is no longer flagged

## [0.8.4] - 2026-08-07

### Fixed

- `Style/DisallowDelegate` — own state reached through a call on it is no longer flagged
- `Style/DisallowDelegate` — an argument rooted at the collaborator being forwarded to is flagged again
- `Style/DisallowDelegate` — own state read through an explicit `self` is no longer flagged
- `Style/DisallowDelegate` — a call reached through safe navigation counts as the call it is, on both the receiver and the argument side

## [0.8.3] - 2026-08-06

### Fixed

- `Style/DisallowDelegate` — own state passed through a splat, a double splat, an array or a block is no longer flagged
- `Style/DisallowDelegate` — `each` in a class prepending `Enumerable` is no longer flagged
- `Style/DisallowDelegate` — a chained receiver carrying an own state argument is flagged again
- `Style/DisallowDelegate` — `each` in a singleton class is flagged again

## [0.8.2] - 2026-08-06

### Fixed

- `Style/DisallowDelegate` — `each` in a class including `Enumerable` is no longer flagged
- `Style/DisallowDelegate` — a method composing its own state into the call is no longer flagged

## [0.8.1] - 2026-08-06

### Fixed

- `Style/DisallowDelegate` — a method answering about its own class is no longer flagged

## [0.8.0] - 2026-08-05

### Changed

- `Style/DisallowDelegate` — a method that forwards its own name to a collaborator is flagged

## [0.7.1] - 2026-08-05

### Removed

- `Style/ConditionalAssignment` configuration — the stock default governs assignment from a conditional again

## [0.7.0] - 2026-08-05

### Added

- `Style/DisallowDelegate` — automatic delegation is flagged
- `Style/DisallowTernary` — the ternary conditional is flagged

### Changed

- `Rails/Delegate` disabled — it asks for the macro `Style/DisallowDelegate` forbids
- `Style/MultilineTernaryOperator`, `Style/NestedTernaryOperator` and `Style/TernaryParentheses` disabled — they shape a construct `Style/DisallowTernary` forbids outright
- `Style/ConditionalAssignment` configured to `assign_inside_condition` — a conditional that decides a value assigns it in each branch, and ternaries are left to `Style/DisallowTernary`

## [0.6.0] - 2026-08-05

### Added

- `Naming/RescuedExceptionsVariableName` configured to `exception` — a rescued exception is no longer bound to a single-letter name

## [0.5.1] - 2026-06-29

### Fixed

- `RSpec/Dialect` no longer remaps `subject`/`subject!` to `let`; only `let!` is remapped. The blind identifier rename rewrote value references such as `expect(subject)` into invalid `expect(let)`

## [0.5.0] - 2026-06-29

### Changed

- Require `rubocop` `>= 1.87` — earlier versions drop the host project's `AllCops/Exclude` when this plugin's config is merged

### Fixed

- `Rails/BidirectionalAssociation` no longer crashes on associations with non-literal options (e.g. `inverse_of: nil`); associations that explicitly opt out of an inverse are skipped

## [0.4.0] - 2026-06-29

### Added

- `Layout/MultilineMethodCallIndentation` configured to `indented` — multiline method-call chains indent continuation calls one step from the receiver instead of aligning with the first call

## [0.3.0] - 2026-06-19

### Added

- `RSpec/Dialect` configured to forbid `subject`, `subject!` and `let!` in favor of a lazy `let`

## [0.2.3] - 2026-05-30

### Fixed

- `Rails/OrderedMacros` sorts `:through` associations as a separate trailing group instead of interleaving them alphabetically — a `:through` association declared after its target association is no longer flagged

## [0.2.2] - 2026-05-30

### Fixed

- `RSpec/InverseOfMatcher` no longer demands `.inverse_of` on polymorphic associations — it reads the polymorphic declaration from the model instead of the spec matcher chain
- `RSpec/InverseOfMatcher` classifies a nested class by its own superclass instead of the first `class` line in the file — a nested root model is no longer misread as an STI subclass

## [0.2.1] - 2026-05-29

### Fixed

- `RSpec/InverseOfMatcher` no longer crashes RuboCop — it classifies root vs subclass statically (reading the model file) instead of loading the model class

## [0.2.0] - 2026-05-29

### Added

- Disable stock `Rails/InverseOf` and `Style/SafeNavigation`, which are superseded or contradicted by 4Shark cops

### Changed

- Cop names aligned with RuboCop naming conventions
- `RSpec/LetNotInContext` renamed to `RSpec/OverwrittenLet` and relaxed to flag only a `let` that overrides one from an outer scope

## [0.1.0] - 2026-05-29

- Initial release

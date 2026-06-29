## [Unreleased]

### Changed

- Require `rubocop` `>= 1.87` — earlier versions drop the host project's `AllCops/Exclude` when this plugin's config is merged

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

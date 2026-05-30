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

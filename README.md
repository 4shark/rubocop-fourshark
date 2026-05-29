# rubocop-fourshark

A RuboCop extension that encodes 4Shark's Ruby, Rails, and RSpec conventions as enforceable cops.

## Why this gem exists

4Shark has its own definition of good Ruby/Rails/RSpec code. Two needs the stock RuboCop ecosystem does not cover on its own:

1. **Conventions stock RuboCop has no cop for.** Rules like "every association declares `inverse_of`", "`belongs_to` is `optional: true` with manual presence validation", or "no associations inside factories" are 4Shark decisions with no equivalent in `rubocop-rails`/`rubocop-rspec`. This gem ships them as real cops.
2. **Stock conventions 4Shark deliberately rejects.** RuboCop's defaults nudge toward patterns 4Shark does not want — safe navigation (`&.`) and `try` being the clearest examples. Rather than each repo re-litigating the same `.rubocop.yml` overrides, the position is made enforceable in one place: a custom cop that flags the rejected construct.

The goal is a single dependency that every 4Shark Ruby repository inherits, so the conventions are identical across all of them — and a new convention is added once, here, instead of in each repository.

## Installation

The gem is published to RubyGems. Add it to the application's `Gemfile`:

```ruby
gem 'rubocop-fourshark', require: false
```

or:

```bash
bundle add rubocop-fourshark --require=false
```

Then activate it as a plugin in `.rubocop.yml`:

```yaml
plugins:
  - rubocop-fourshark
```

Activating the plugin auto-loads the gem's `config/default.yml`, which enables every cop below.

> **Note — plugins are not transitively activated.** `rubocop-fourshark` depends on the upstream plugins (`rubocop-rails`, `rubocop-rspec`, `rubocop-rspec_rails`, `rubocop-performance`, `rubocop-factory_bot`), but `lint_roller` does not auto-activate a plugin's dependencies. Each repo still lists the upstream plugins it uses in its own `plugins:` block.

## Cops

All cops are **enabled by default** the moment the plugin is activated. Cops scoped to a path (models, specs, factories) only run on files matching that path. Each cop's source file under [`lib/rubocop/cop`](lib/rubocop/cop) carries runnable `@example` blocks showing the bad/good shapes.

### Style

| Cop | Intent |
|---|---|
| `Style/DisallowSafeNavigation` | Flags safe navigation (`&.`). 4Shark rejects it — a `&.` chain silently swallows a `nil` that usually signals a real bug. Use an explicit conditional so the `nil` case is handled on purpose. |
| `Style/DisallowTry` | Flags `try` / `try!`. Same rationale as safe navigation — it hides the `nil`/missing-method case instead of handling it explicitly. |

### Layout

| Cop | Intent |
|---|---|
| `Layout/MultiLineBlockSpacing` | Requires a blank line between two consecutive statements when either spans multiple lines, so multi-line statements read as distinct blocks. |

### Rails (models)

| Cop | Intent |
|---|---|
| `Rails/AssociationInverseOf` | Every association (`belongs_to`/`has_many`/`has_one`) must declare `inverse_of`, so both sides resolve to the same in-memory object. Scoped to `app/models`. |
| `Rails/BidirectionalAssociations` | An association must be declared on both sides of the relationship — the opposite model must carry the matching association. Scoped to `app/models`. |
| `Rails/OptionalBelongsTo` | `belongs_to` must be `optional: true` with manual `validates :x_id, presence: true`, skipping the per-record existence `SELECT` that Rails adds by default. Scoped to `app/models`. |
| `Rails/AlphabeticalMacros` | Same-kind class macros (associations, validations, scopes) must be sorted alphabetically within their group. Scoped to `app/models`. |

### RSpec (specs)

| Cop | Intent |
|---|---|
| `RSpec/AssociationInverseOf` | Root models must assert `.inverse_of` in association specs; subclasses must not. Scoped to `spec/models`. |
| `RSpec/LetNotInContext` | `let` is declared at the top level of the example group, not inside a `context`. Keeps setup visible and avoids context-local surprises. |
| `RSpec/NoConditionalInLet` | A `let` must not contain conditional logic — branch with separate `context`s instead of an `if` inside the memoized helper. |
| `RSpec/NoFactoryBotInBefore` | Object creation belongs in `let`, not `before`. `before` is for actions, not for building the subjects under test. |

### FactoryBot (factories)

| Cop | Intent |
|---|---|
| `FactoryBot/NoAssociationsInFactory` | No associations declared inside a factory — they trigger cascading object creation and callbacks. Set the association manually in the spec. Scoped to `spec/factories`. |

The full rationale behind each convention (the "why this is good 4Shark code") lives in the team's engineering docs; this README states the intent each cop enforces. One convention deviates from a safe Rails default and is worth spelling out — see below.

### Why `belongs_to` is `optional: true` by default

4Shark never exposes internal database IDs across its API and upload boundaries. Clients send their **own** identifiers; each external identifier is mapped to its internal record (a surrogate-key cross-reference), and that lookup is scoped to the client's account — so it confirms both that the record **exists** and that it **belongs to the caller**, in a single step.

By the time an association is assigned, existence and ownership have already been verified — more strictly than Rails would. Rails' default `belongs_to` (`optional: false`) then adds an existence `SELECT` per record on top of that: redundant work, and at high API throughput a measurable per-request cost.

So the convention is:

- `belongs_to` is always declared `optional: true` (enforced by `Rails/OptionalBelongsTo`), turning off Rails' automatic existence validation.
- Presence is validated manually with `validates :x_id, presence: true` **where the business rule requires it** — case by case, not globally (which is why no cop enforces the presence side).

A deliberate performance trade-off backed by the external-identifier mapping — not an omission.

## Development

After checking out the repo, install dependencies and run the suite:

```bash
bundle install
bundle exec rspec      # cop specs
bundle exec rubocop    # self-lint (includes rubocop-internal_affairs)
```

Each new cop ships with a spec (`expect_offense` / `expect_no_offenses`) and a `config/default.yml` entry.

## Releasing

This project does **not** use HubFlow. Releases are cut from `main`: feature branches merge into `main` via PR, the version is bumped, a `vX.Y.Z` tag is created from `main`, and the gem is published to RubyGems. Consuming repos depend on the published version in their `Gemfile`.

## License

Released under the [MIT License](https://opensource.org/licenses/MIT).

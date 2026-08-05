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

> **Note — list `rubocop-fourshark` last.** When this gem configures a cop that an upstream plugin also ships (e.g. `RSpec/Dialect`, owned by `rubocop-rspec`), RuboCop merges the plugins' default config in `plugins:` order and the **last** one wins. List `rubocop-fourshark` **after** the upstream plugins so its configuration is the one that takes effect:
>
> ```yaml
> plugins:
>   - rubocop-rspec
>   - rubocop-rspec_rails
>   - rubocop-rails
>   - rubocop-performance
>   - rubocop-factory_bot
>   - rubocop-fourshark
> ```

## Cops

All cops are **enabled by default** the moment the plugin is activated. Cops scoped to a path (models, specs, factories) only run on files matching that path. Each cop's source file under [`lib/rubocop/cop`](lib/rubocop/cop) carries runnable `@example` blocks showing the bad/good shapes.

### Cop naming

Cop names follow RuboCop's empirical convention — a noun phrase describing the construct or smell, no `Disallow*`/`No*` prefixes — with two deliberate exceptions:

- **`Style/DisallowDelegate` / `Style/DisallowSafeNavigation` / `Style/DisallowTernary` / `Style/DisallowTry`** keep the `Disallow*` prefix. RuboCop has no idiom for "forbid a construct it otherwise permits" (it uses `EnforcedStyle` on one cop), and the natural noun name is already taken by a stock cop with the *opposite* intent — `Style/SafeNavigation` *converts to* `&.`, `Rails/Delegate` *converts to* `delegate`. `Disallow*` is unambiguous and collision-free.
- **`Rails/MandatoryInverseOf`** is named to distinguish it from stock `Rails/InverseOf`, which only flags associations where Active Record cannot auto-detect the inverse. Ours mandates `inverse_of` on *every* association — a strict superset — so the gem disables the stock cop (below).

### Stock cops disabled

Where a 4Shark cop supersedes or contradicts a stock cop, `config/default.yml` turns the stock one off:

| Disabled stock cop | Why |
|---|---|
| `Rails/Delegate` | contradicts `Style/DisallowDelegate` — it turns an explicit method into `delegate`, we forbid the macro |
| `Rails/InverseOf` | superseded by `Rails/MandatoryInverseOf` (covers its cases and more) |
| `Style/MultilineTernaryOperator` | superseded by `Style/DisallowTernary` — it shapes a construct we forbid outright |
| `Style/NestedTernaryOperator` | superseded by `Style/DisallowTernary` — same |
| `Style/SafeNavigation` | contradicts `Style/DisallowSafeNavigation` — it pushes `&.`, we forbid it |
| `Style/TernaryParentheses` | superseded by `Style/DisallowTernary` — same |

### Style

| Cop | Intent |
|---|---|
| `Style/DisallowDelegate` | Flags automatic delegation (`delegate`, `delegate_missing_to`, `def_delegator(s)`, `DelegateClass`). A `delegate` line is a macro call, not a definition, so `grep 'def foo'` and jump-to-definition find nothing — the community name for the smell is Fowler's Middle Man. Write the method, or let the caller ask the object that knows. |
| `Style/DisallowSafeNavigation` | Flags safe navigation (`&.`). 4Shark rejects it — a `&.` chain silently swallows a `nil` that usually signals a real bug. Use an explicit conditional so the `nil` case is handled on purpose. |
| `Style/DisallowTernary` | Flags the ternary conditional (`cond ? a : b`). `?` and `:` are punctuation that already mean other things in Ruby (`valid?`, `:symbol`), and the ternary hides a branch inside an expression where skimming misses it. Use an explicit `if`/`else`. |
| `Style/DisallowTry` | Flags `try` / `try!`. Same rationale — it hides the `nil`/missing-method case instead of handling it explicitly. |

### Layout

| Cop | Intent |
|---|---|
| `Layout/MultilineStatementSpacing` | Requires a blank line between two consecutive statements when either spans multiple lines, so multi-line statements read as distinct units. |

### Naming

| Cop | Intent |
|---|---|
| `Naming/RescuedExceptionsVariableName` | A rescued exception is bound to `exception` (`_exception` when unread), not the cop's default `e` — 4Shark bans single-letter variables, and this is the one slot where a stock cop demanded one. Stock cop, configured via `PreferredName`; autocorrects. |

### Rails (models)

| Cop | Intent |
|---|---|
| `Rails/MandatoryInverseOf` | Every association (`belongs_to`/`has_many`/`has_one`) must declare `inverse_of`, so both sides resolve to the same in-memory object. Stricter than stock `Rails/InverseOf`, which only fires when AR can't auto-detect the inverse. Scoped to `app/models`. |
| `Rails/BidirectionalAssociation` | An association must be declared on both sides of the relationship — the opposite model must carry the matching association. Scoped to `app/models`. |
| `Rails/OptionalBelongsTo` | `belongs_to` must be `optional: true` (see the rationale below). Scoped to `app/models`. |
| `Rails/OrderedMacros` | Same-kind class macros (associations, validations, scopes) must be sorted alphabetically within their group. Scoped to `app/models`. |

### RSpec (specs)

| Cop | Intent |
|---|---|
| `RSpec/Dialect` | Use `let`, never `subject` or `let!` — every `subject`/`subject!`/`let!` is flagged in favor of a lazy `let` (force creation in an explicit `before`, not with `let!`). The implicit subject behind `is_expected` is a different method and is left untouched. Stock cop, configured via `PreferredMethods`. |
| `RSpec/InverseOfMatcher` | Root models must assert `.inverse_of` in association specs; subclasses must not (it belongs to the parent). Scoped to `spec/models`. |
| `RSpec/OverwrittenLet` | A `let`/`let!` must not override one defined in an outer example group — shadowing makes it ambiguous which value applies. Scenario-specific `let`s, and the same name across sibling contexts, are fine. |
| `RSpec/ConditionalInLet` | A `let` must not contain conditional logic (`if`/`case`) — branch with separate `context`s instead. A ternary inside a `let` is flagged by `Style/DisallowTernary`, not by this cop. |
| `RSpec/FactoryBotInBefore` | Object creation belongs in `let`, not `before`. `before` is for actions, not for building the subjects under test. |

### FactoryBot (factories)

| Cop | Intent |
|---|---|
| `FactoryBot/AssociationInFactory` | No associations declared inside a factory — they trigger cascading object creation and callbacks. Set the association manually in the spec. Scoped to `spec/factories`. |

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

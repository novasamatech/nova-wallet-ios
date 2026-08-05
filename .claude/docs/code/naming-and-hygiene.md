# Naming & Code Hygiene

## Lint & Format Configuration

`.swiftlint.yml`:

| Rule                | Setting                                        |
|---------------------|------------------------------------------------|
| `nesting`           | type and statement level max 3                 |
| `type_body_length`  | warning 400, error 500                          |
| `large_tuple`       | warning 6, error 7                              |
| `identifier_name`   | `id` allowed                                    |
| `switch_case_alignment` | disabled                                    |
| excluded            | `R.generated.swift`, both test targets, extension's `R.generated.swift`, `vendor/bundle` |

`.swiftformat`: Swift 5.3 mode, `--wraparguments before-first`, `--wrapparameters before-first`,
`isEmpty` enabled; `sortedImports`, `sortedSwitchCases`, `trailingCommas`,
`wrapMultilineStatementBraces` disabled.

Both run as Xcode build phases (skipped when `RUN_IN_CI=true`) via `Scripts/lint.sh` and
`Scripts/format.sh`, pinned through Mint.

`// swiftlint:disable` is used sparingly (~90 sites, mostly `function_body_length` on large
composition-root factories). Prefer splitting the code; if you disable, do it with
`// swiftlint:disable:next <rule>` on the narrowest scope.

## Naming

- **Protocols end with `Protocol`** — except the trait-style mix-ins that read as adjectives
  (`AlertPresentable`, `Localizable`, `ViewHolder`, `AnyProviderAutoCleaning`, `DataValidating`).
- **VIPER suffixes are mandatory and exact**: `ViewController`, `ViewLayout`, `Presenter`,
  `Interactor`, `Wireframe`, `Protocols`, `ViewFactory`.
- **Factories say what they produce**: `*OperationFactory` (operation wrappers), `*ViewModelFactory`,
  `*RepositoryFactory`, `*ServiceFactory`.
- **Methods describe intent, not mechanism**: `showConfirmation`, `refreshFee`, `syncUp`,
  `didReceive(balance:)` — not `handleData`, `doWork`, `process`.
- **Interactor→Presenter callbacks are `didReceive(...)`**, one overload per payload type.
- **No abbreviations** in names: `currentPayment`, not `p`. Single letters only as closure shorthand
  (`$0`) and generic parameters (`T`, `U`).
- Domain typealiases are used where a bare `String`/`Data` would be ambiguous: `ChainModel.Id`,
  `MetaAccountModel.Id`, `AccountId`, `AccountAddress`. Prefer them over primitives in signatures.

## Structure

- **Private methods live in a `private extension`** below the type, under a `// MARK: Private`
  comment. The main type body holds stored properties, init, and protocol conformances.
- **Protocol conformances go in their own extension** (`extension SomePresenter: SomeInteractorOutputProtocol { … }`).
- **Constants go in a nested `enum Constants`** in the file that uses them; no magic numbers in
  layout or maths.
- **Structs for data and state, classes for services and objects with identity/lifecycle.**
- **Keep files under ~400 lines.** SwiftLint warns at 400 for a type body and errors at 500; large
  files are routinely flagged in review. Split by extracting view models, factories, or subviews.
- **Function bodies under ~50 lines and at most ~5 parameters.** When more data is needed, group it
  into a `struct` (this is why `*Params`/`*Context`/`Settings` structs are common in the codebase).

## Comments

The codebase is deliberately comment-light — most files have zero or one comment.

- Comment *why*, never *what*. `// Note: transferCompletion is not called for delayed transfers` is
  the kind that earns its place.
- Document non-obvious protocols, invariants, and cross-subsystem contracts.
- Do not restate the code, do not leave commented-out code, do not add section banners beyond
  `// MARK:`.
- `// TODO:` is acceptable for a pending integration, but must say what unblocks it and be greppable.

## Hygiene Checklist

- Dead code removed — unused methods, properties, imports, and `R.` references.
- No debug leftovers: no `print`, no temporary `Task`/timers, no commented experiments,
  no hardcoded test addresses.
- No unused parameters threaded through a call chain.
- All user-visible strings localized (code/localization.md).
- All colors/fonts/images via `R.`/style extensions (code/ui-uikit.md).
- All URLs and keys in `ApplicationConfig`/`GlobalConfig`/`CIKeys` (architecture/services-lifecycle.md).
- Generated files not hand-edited (code/project-layout.md).
- The diff contains no unrelated changes.

## Hard Rules

1. **Depend on protocols, inject dependencies.** Even singleton-backed services are injected through
   `init` from the ViewFactory — that is what keeps modules mockable.
2. **No force unwraps or `fatalError`** outside the two sanctioned spots (`init?(coder:)` stubs,
   `ViewHolder.rootView`). Throw a typed error instead.
3. **No `print`/`NSLog`.** Injected `LoggerProtocol` only.
4. **Nesting ≤ 3.** If you need more, extract a function or a type.
5. **Peer files travel together** — `Protocols.swift` with any layer signature change, the Cuckoo
   mock list with any new mocked protocol, tests with any behaviour change.

## Related

- code/project-layout.md — where a file belongs and the naming-by-location table
- code/build-and-tooling.md — how lint/format run
- review/code-checklist.md — the review form of these rules

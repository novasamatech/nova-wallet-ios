# Code Review Checklist

File-by-file review. For each violation note severity (blocking/major/minor), quote `file:line`, and
give a concrete fix.

## Error Handling

- [ ] No force unwraps (`!`), no `as!` — guard/throw instead
- [ ] No `fatalError` outside `init?(coder:)` stubs and `ViewHolder.rootView`
- [ ] No `try?` collapsing a failure into a default; no `?? 0` on amounts
- [ ] Typed error enum per domain; `CommonError` only for infrastructure failures
- [ ] User-facing errors go through `ErrorPresentable` + `ErrorContentConvertible`, localized
- [ ] `present(error:)` return value handled with a fallback
- [ ] Cancellation is not reported as an error

**Ref:** code/error-handling.md

## Validation

- [ ] Preconditions on user actions are `DataValidating` validators, not inline `if`s
- [ ] Correct severity: `.error` aborts, `.warning` asks, `.asyncProcess` waits
- [ ] Validators reuse `BaseDataValidatingFactoryProtocol` where a check already exists
- [ ] Validation runs before every submission path

**Ref:** architecture/transactions.md

## Concurrency

- [ ] No `async`/`await`, actors, `AsyncStream`, or new Combine usage
- [ ] Results read with `extractNoCancellableResultData()`, not `result` + unwrap
- [ ] Wrappers composed with `insertingHead`/`insertingTail`/`addDependency`/`OperationCombiningService`
- [ ] `[weak self]` in every operation callback
- [ ] `CancellableCallStore` used for anything the user can re-trigger; cancelled on teardown
- [ ] No `waitUntilFinished: true` on the main thread
- [ ] Queue taken from `OperationManagerFacade` and injected, not created inline
- [ ] Debounce (`Debouncer`) on rapidly changing inputs feeding network calls

**Ref:** code/concurrency.md

## Subscriptions & Providers

- [ ] Providers stored in a property (not discarded)
- [ ] Cleared via `AnyProviderAutoCleaning` before re-subscribing
- [ ] `.failure` branches handled, not ignored
- [ ] Remote subscription ids detached
- [ ] `EventCenter` observers removed on teardown

**Ref:** architecture/data-flow.md

## UI

- [ ] Layout only in `ViewLayout`; ViewController binds and forwards
- [ ] Subviews built with `.create { }`; SnapKit for constraints
- [ ] Colors via `R.color.*`, fonts via `UIFont` style extensions, images via `R.image.*`
- [ ] Composite styles via `apply(style:)` / `applyDefaultStyle()` rather than ad-hoc property sets
- [ ] No light-mode branches or `traitCollection` appearance checks
- [ ] No magic numbers — nested `Constants` enum
- [ ] Existing components from `Common/View`, `Common/ViewController`, `UIKit_iOS` reused
- [ ] Cells bind view models; no formatting or image loading logic inline
- [ ] Images loaded through `ImageViewModelProtocol` (cancellable)
- [ ] `required init?(coder:)` marked `@available(*, unavailable)`

**Ref:** code/ui-uikit.md

## Localization

- [ ] No hardcoded user-visible strings
- [ ] Every string uses `R.string(preferredLanguages: locale.rLanguages).localizable.*`
- [ ] `applyLocalization()` implemented and re-runs `setupLocalization()`
- [ ] Locale-dependent factory output is `LocalizableResource<T>`
- [ ] Amounts/prices/dates via formatter factories, not interpolation
- [ ] New keys added to `en.lproj` (and the extension catalog when push-facing)

**Ref:** code/localization.md

## Naming & Hygiene

- [ ] VIPER suffixes exact; protocols end with `Protocol` (except `*Presentable`/trait style)
- [ ] Descriptive names, no abbreviations, domain typealiases over raw `String`/`Data`
- [ ] Interactor→Presenter callbacks named `didReceive(...)`
- [ ] Private methods in a `private extension` under `// MARK: Private`
- [ ] Comments explain *why*; no restating code, no commented-out code
- [ ] Dead code, unused imports, and debug leftovers removed
- [ ] No `print`/`NSLog`; logger injected, not `Logger.shared` in a method body
- [ ] No secrets, mnemonics, or keys in logs or error text
- [ ] Nesting ≤ 3; functions ≤ ~50 lines; ≤ ~5 parameters
- [ ] Type bodies under 400 lines (SwiftLint warning threshold)
- [ ] `swiftlint:disable` avoided, or scoped with `:next` and justified

**Ref:** code/naming-and-hygiene.md

## Dependency Injection

- [ ] Dependencies injected through `init` from the `ViewFactory`
- [ ] Protocols, not concrete types
- [ ] Non-optional when always present
- [ ] No `.shared` singleton access inside Presenter/Interactor/service method bodies

**Ref:** architecture/services-lifecycle.md

## Persistence

- [ ] Repository + mapper; no direct CoreData access
- [ ] Mapper `transform` throws on corrupt data
- [ ] `BigUInt` stored as `String` per convention
- [ ] Predicates in `NSPredicate` extensions, not inline
- [ ] `SettingsManager` instead of `UserDefaults`
- [ ] Schema change accompanied by a model version + migration

**Ref:** code/data-persistence.md, code/migrations.md

## Chain & Networking

- [ ] Connection/runtime from `ChainRegistry`
- [ ] Storage paths and calls from declared types, not string tuples
- [ ] Decoding uses the chain's coder factory
- [ ] Typed HTTP constants (`HttpMethod`, `HttpContentType`, `HttpHeaderKey`)
- [ ] `Decodable` DTOs parsed at the boundary; no `[String: Any]` passed deeper
- [ ] URLs from config; no reachability pre-checks; no custom retry over the connection layer

**Ref:** code/networking.md, architecture/chain-registry.md

## Tests

- [ ] Test file mirrors the source path
- [ ] Existing generators/stubs reused (`ChainModelGenerator`, `AccountGenerator`, `*Stub`)
- [ ] Cuckoo mocks regenerated; `Cuckoofile.toml` updated for new mocked protocols
- [ ] No `sleep()`; `XCTestExpectation` + `wait(for:timeout:)`
- [ ] In-memory storage facades, never the real store
- [ ] Behaviour change comes with test updates (presenter, mapper, maths, migration)

**Ref:** code/testing.md

## PR Hygiene

- [ ] No unrelated changes in the diff
- [ ] Peer files updated (`Protocols.swift`, mocks, tests)
- [ ] `Package.resolved` included with any dependency bump
- [ ] Generated files not hand-edited
- [ ] Style consistent with surrounding code

## Comment Style

```
**[severity]** `file:line`

Description of the issue.

**Fix:** Concrete suggestion or code example.

*Ref: checklist-section*
```

## Verdict Format

```
## Code Review

**Verdict:** X blocking / Y major / Z minor

### Blocking
- [file:line] Description. Fix: ...

### Major
- [file:line] Description. Fix: ...

### Minor
- [file:line] Description. Suggestion: ...
```

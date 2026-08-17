# Error Handling, Validation & Logging

## Typed Errors

Every domain declares its own `Error` enum. Interactors report them through the module's
`InteractorOutputProtocol`:

```swift
enum AssetReceiveInteractorError: Error {
    case accountFetchFailed
    case qrGenerationFailed(Error)
}

protocol AssetReceiveInteractorOutputProtocol: AnyObject {
    func didReceive(error: AssetReceiveInteractorError)
}
```

- `CommonError` (`Common/Model/CommonError/`) covers the generic cases: `.undefined`,
  `.databaseSubscription`, `.dataCorruption`, `.noDataRetrieved`. Use it for infrastructure failures,
  not as a catch-all for domain problems.
- Never surface a raw `Error` to the Presenter when the module can distinguish causes — the
  distinction is what lets the UI offer the right recovery.

## Presenting Errors

Errors reach the user through the wireframe:

```swift
protocol ErrorPresentable: AnyObject {
    @discardableResult
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool
}
```

`present(error:)` returns `false` if it did not know how to display the error — the caller then falls
back to a generic alert:

```swift
if !wireframe.present(error: error, from: view, locale: selectedLocale) {
    _ = wireframe.present(error: CommonError.undefined, from: view, locale: selectedLocale)
}
```

To make an error displayable, conform it to `ErrorContentConvertible`:

```swift
extension SomeError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        ErrorContent(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.someTitle(),
            message: R.string(preferredLanguages: locale.rLanguages).localizable.someMessage()
        )
    }
}
```

Domain-specific copy goes into a `*ErrorPresentable` protocol (e.g. `BaseErrorPresentable`,
`PhishingErrorPresentable`, staking/transfer error presentables) mixed into the wireframe.

Recovery mix-ins: `CommonRetryable` (generic retry alert), `FeeRetryable` (fee refresh),
`ExtrinsicSigningErrorHandling`, `TransactionExpiredPresentable`, `CancelOperationPresentable`.

## Validation Before Actions

User-facing preconditions are **validators**, not `if` statements. See
architecture/transactions.md for the full pattern:

```swift
DataValidationRunner(validators: [
    dataValidatingFactory.has(fee: fee, locale: locale) { [weak self] in self?.refreshFee() },
    dataValidatingFactory.canPayFeeSpendingAmount(...)
]).runValidation { [weak self] in
    self?.interactor.submit(...)
}
```

`DataValidationProblem` has three severities: `.error` (abort), `.warning` (ask, then resume),
`.asyncProcess` (wait, then resume). Choosing the right one is what makes the UX consistent across
flows.

## Failure Policy

1. **Throw instead of force-unwrapping.** `guard let … else { throw SomeError.x }`. Force unwraps in
   non-test code are a review blocker; the only accepted `fatalError`s are the
   `init?(coder:)` stubs and `ViewHolder.rootView`'s type assertion.
2. **No silent fallbacks.** Never `try?` a decode into a default value, never `?? 0` a balance, never
   swallow an error in a completion handler. If data is missing, propagate it.
3. **Errors propagate through operations** via `extractNoCancellableResultData()`; do not convert a
   failed wrapper into an empty result.
4. **Cancellation is not an error.** `CancellableCallStore` drops late callbacks; don't report a
   cancelled request as a failure to the user.
5. **Partial data gets an explicit state.** Prefer a loading/empty/error view state
   (`GenericViewState`, `LoadableViewModelState`) over rendering zeros.

## Logging

`LoggerProtocol` over SwiftyBeaver. **Inject it** (`logger: LoggerProtocol`) through the ViewFactory;
`Logger.shared` belongs in the composition root, not inside a service method.

```swift
logger.error("Unexpected error on chains update: \(error)")
logger.debug("Sync mode \(chain.syncMode) applied to \(chain.name)")
```

Levels: `error` (something broke), `warning` (recovered but suspicious), `info` (lifecycle),
`debug`/`verbose` (development detail). Console minimum level is `.verbose` in `F_DEV` builds and
`.info` otherwise.

Never log: mnemonics, seeds, private keys, keystore contents, pincode, push payload secrets. Addresses
and chain ids are fine.

`print`/`NSLog` are not used — always the injected logger.

## Hard Rules

1. Typed error enums per domain; `CommonError` only for infrastructure.
2. `ErrorPresentable` + `ErrorContentConvertible` for anything the user sees; localized copy always.
3. No force unwraps, no silent fallbacks, no `try?`-to-default.
4. Preconditions on user actions are `DataValidating` validators.
5. Logger is injected, never `Logger.shared` inside a method body.
6. No secrets in logs or error messages.

## Related

- architecture/transactions.md — the validation runner in submission flows
- code/navigation.md — the presentable mix-ins that render errors
- code/concurrency.md — how errors travel through operation wrappers

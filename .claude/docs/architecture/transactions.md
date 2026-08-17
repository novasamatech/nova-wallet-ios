# Transactions — Extrinsics, Fees, Validation, Submission

Every on-chain write in the app follows the same shape:

```
build call → estimate fee → validate → sign → submit → track status → persist/notify
```

## ExtrinsicService (Substrate)

`Common/Services/ExtrinsicService/Substrate/`. Create one with `ExtrinsicServiceFactory`, scoped to a
chain and a sender account; do not instantiate `ExtrinsicService` by hand in a module.

`ExtrinsicServiceProtocol` surface:

| Method                    | Use                                                            |
|---------------------------|----------------------------------------------------------------|
| `estimateFee(_:payingIn:runningIn:completion:)` | Fee for one call closure                    |
| `estimateFeeWithSplitter(_:...)`                | Fee for a batch built by `ExtrinsicSplitting` |
| `submit(_:payingIn:signer:runningIn:completion:)` | Fire and forget (returns tx hash)         |
| `submitAndWatch(_:...)`   | Submit + subscribe to extrinsic status updates                 |
| `buildExtrinsic(_:...)`   | Produce the signed payload without submitting (dry run, export)|
| `cancelExtrinsicWatch(for:)` | Stop a watch subscription                                   |

Calls are described by an `ExtrinsicBuilderClosure`:

```swift
let closure: ExtrinsicBuilderClosure = { builder in
    try builder.adding(call: callFactory.transfer(to: accountId, amount: amount))
}
```

Key collaborators:

- **`ExtrinsicSplitter` / `ExtrinsicSplitting`** — splits a set of calls into as many extrinsics as
  the chain's weight/length limits allow. Use it whenever the number of calls is data-driven
  (payouts, multi-unlock, batch votes), instead of guessing a batch size.
- **`ExtrinsicSenderResolution`** — resolves who actually signs (self, proxy delegate, multisig
  signatory) and rewrites the call accordingly. Delegated wallets work because of this layer; never
  bypass it by signing with the delegator's account directly.
- **`ExtrinsicFeeEstimationRegistry` / `FeeManaging`** — chooses the fee payment mode. `payingIn:`
  lets the user pay fees in a non-native asset (`FeeViaSwap`, asset conversion); `nil` means native.
- **Era / nonce / metadata hash factories** — `MortalEraOperationFactory`,
  `TransactionNonceOperationFactory`, `MetadataHashOperationFactory` (metadata shortening for
  hardware signers). These are wired by the factory; features don't call them.

Calls themselves are built from `Common/Substrate/Calls/` (typed `RuntimeCall<Args>` factories).
Add a new call there, not inline in an Interactor.

## EVM Transactions

`Common/Services/ExtrinsicService/Evm/`: `EvmTransactionService` +
`EvmTransactionBuilder`, with `EvmTransactionFeeProxy` for fee estimation and
`EvmFallbackGasLimit` when estimation fails. The flow mirrors the substrate one
(build → estimate → sign via `SigningWrapperFactory.createEthereumSigner` → submit).

## Fee Handling

- Fees are modelled by `ExtrinsicFeeProtocol` / `FeeOutputModel`, never raw `BigUInt` in the UI.
- Fee requests are debounced/re-run when the amount or recipient changes. Use
  `ExtrinsicFeeProxy`-style proxies (`XcmExtrinsicFeeProxy`, `EvmTransactionFeeProxy`) which key
  in-flight requests by an identifier so late responses for stale inputs are dropped.
- `FeeRetryable` (`Common/Protocols/`) gives the standard "fee failed → retry" alert.
- Never submit with a stale fee: the confirm screen re-validates `has(fee:)` before submission.

## Validation

Pre-submission checks use the `DataValidating` framework (`Common/Validation/`):

```swift
let validators: [DataValidating] = [
    dataValidatingFactory.has(fee: fee, locale: locale) { [weak self] in self?.refreshFee() },
    dataValidatingFactory.canPayFeeSpendingAmount(balance: ..., fee: ..., locale: locale),
    dataValidatingFactory.exsitentialDepositIsNotViolated(...),
    dataValidatingFactory.accountIsNotSystem(for: recipientId, locale: locale)
]

DataValidationRunner(validators: validators).runValidation { [weak self] in
    self?.view?.didStartLoading()
    self?.interactor.submit(...)
}
```

How it works:

- `DataValidationRunner` runs validators **in order** and stops at the first `DataValidationProblem`.
- `.error` aborts. `.warning` and `.asyncProcess` pause; when the user confirms the warning (or the
  async check completes) the validator calls back through `DataValidatingDelegate` and the runner
  resumes from the next validator.
- Common validators live in `BaseDataValidatorFactory` (`canSpendAmount`, `canPayFee`,
  `canPayFeeSpendingAmount`, `has(fee:)`, `exsitentialDepositIsNotViolated`, `accountIsNotSystem`,
  `notViolatingMinBalancePaying`). Feature-specific factories extend it
  (`Modules/Transfer/Validation/`, `Modules/Staking/Validation/`, `Modules/Vote/Governance/Validating/`).
- Validators own their error presentation via a `*ErrorPresentable` protocol on the wireframe.

**Add new checks as validators**, not as `if` statements in the Presenter's confirm method — that is
how the warning/resume behaviour and the localized error copy stay consistent.

## Submission & Status Tracking

- `submitAndWatch` + `ExtrinsicSubmissionMonitor` / `ExtrinsicStatusService` follow the extrinsic to
  inclusion, decode the block events (`BlockEventsQueryFactory`,
  `ExtrinsicEventsMatching`), and report success/failure with the actual dispatch error.
- `ExtrinsicSubmissionPresenting` (`Common/Protocols/ExtrinsicSubmissionPresentation/`) shows the
  standard "submitted" screen; use `wireframe.presentExtrinsicSubmission(...)` rather than a custom
  alert.
- `PersistentExtrinsicService` (`Common/Services/PersistExtrinsicService/`, built by
  `PersistExtrinsicFactory`) writes the submitted extrinsic into local transaction history so it
  appears immediately in `Modules/TransactionHistory` before the indexer catches up.
- `WalletDelayedExecution` covers flows where the tx is executed later (multisig approval, proxy
  announcement); those do **not** call the normal completion path — check
  `didCompleteSubmition(by:)` handling before assuming success means "done".

## Transfers

`Modules/Transfer/` splits by direction:

- `TransferSetup/OnChain` + `TransferConfirm/OnChain` — same-chain transfers
- `TransferSetup/CrossChain` + `TransferConfirm/CrossChain` — XCM transfers
- `TransferNetworkSelection` — picking the destination chain
- `Validation/` — transfer-specific validators (recipient, ED on destination, min amount)

## XCM

`Common/Services/ExtrinsicService/Substrate/Xcm/`:

| Piece                                    | Role                                                    |
|------------------------------------------|---------------------------------------------------------|
| `XcmModelFactory` / `XcmDynamicModelFactory` | Build the XCM message for a route                   |
| `XcmTransferResolutionService`           | Resolve reserve/destination chain path                   |
| `XcmDynamicCrosschainFeeCalculator` / `XcmLegacyCrosschainFeeCalculator` | Origin + delivery + destination fees |
| `XcmTransferDryRunner`                   | Dry-run the transfer where the chain supports it          |
| `XcmDepositMonitoringService` / `XcmTokensArrivalDetector` | Detect arrival on the destination chain |
| `TokenDepositEventMatching`              | Match deposit events per pallet (assets, balances, ORML)  |

XCM transfer configuration comes from remote JSON (`xcmTransfersURL`, `xcmDynamicTransfersURL` in
`ApplicationConfig`) — never hardcode routes or fee constants.

## Hard Rules

1. **Never sign or submit without running the validators.** Confirm screens call
   `DataValidationRunner` before `interactor.submit(...)`.
2. **Fees are always estimated for the exact call you will submit** — including the batch shape the
   splitter produced.
3. **Respect sender resolution.** Delegated wallets must go through `ExtrinsicSenderResolution`.
4. **Use call factories in `Common/Substrate/Calls/`.** No ad-hoc `RuntimeCall` literals in
   Interactors.
5. **Track what you submit.** Either `submitAndWatch` or persist via `PersistentExtrinsicService`, so
   the user sees the operation in history.
6. **Amounts stay in plank (`BigUInt`) end to end**; convert to `Decimal` only in view model
   factories, using the asset's precision.

## Related

- architecture/wallets-accounts.md — signing wrappers and interactive signers
- architecture/swaps-exchange.md — fee estimation across exchange routes
- code/error-handling.md — validators, error presentables, retry patterns

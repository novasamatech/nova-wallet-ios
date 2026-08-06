# Architecture Review Checklist

Structural review: does the change sit in the right place and use the right mechanism? Run this
before the line-by-line pass in review/code-checklist.md.

## Module Structure

- [ ] New screens are full VIPER modules with all 7 files (or a documented reason not to)
- [ ] `Protocols.swift` updated alongside any layer signature change
- [ ] Module assembled only in its `ViewFactory`; no `Interactor()`/`Presenter()` elsewhere
- [ ] `createView` returns `nil` on missing preconditions instead of force-unwrapping
- [ ] ViewController holds no layout; ViewLayout holds no business logic
- [ ] Interactor imports no UIKit and builds no view models
- [ ] Navigation only in the Wireframe; shared presentation via a `*Presentable` mix-in
- [ ] Ownership: `weak var view`, `weak var presenter`; strong Presenter→Interactor/Wireframe

**Ref:** architecture/viper.md

## Placement

- [ ] Single-consumer code stays local; shared code is hoisted only when a second consumer exists
- [ ] Substrate-primitive helpers in `Common/Substrate/`, domain code in `Common/`, screen code in the module
- [ ] No new abstraction with one call site (no provider/wrapper/factory that just delegates)
- [ ] URLs, endpoints, and keys in `ApplicationConfig`/`GlobalConfig`, or the Sourcery-generated
      per-service enums in `CIKeys.generated.swift` (`EtherscanCIKeys`, `WalletConnectCISecrets`, …) —
      never inline
- [ ] Generated files untouched

**Ref:** code/project-layout.md

## Services & Lifecycle

- [ ] New long-lived service conforms to `ApplicationServiceProtocol` or `SyncServiceProtocol`
- [ ] Registered in `ServiceCoordinator` with **both** `setup()` and `throttle()`
- [ ] Wallet-dependent services handled in `updateOnWalletSelectionChange()` / `updateOnWalletChange(for:)`
- [ ] Services are non-optional dependencies when they always exist
- [ ] Protocols injected, not concrete types or `.shared` reached from method bodies
- [ ] Feature toggles applied at creation/registration, not as early returns inside the feature

**Ref:** architecture/services-lifecycle.md

## Chain Integration

- [ ] Chains, connections, and runtime providers come from `ChainRegistry`
- [ ] No hardcoded node URLs, genesis hashes, or asset ids
- [ ] Storage paths and calls declared as types in `Common/Substrate/`
- [ ] Decoding uses the chain's own coder factory
- [ ] Missing chain/connection/runtime treated as a recoverable state
- [ ] `chainsSubscribe`/`subscribeChainState` unsubscribed on teardown

**Ref:** architecture/chain-registry.md, code/networking.md

## Data Flow

- [ ] Right mechanism chosen: local subscription vs. one-shot query vs. remote subscription vs. event
- [ ] Providers held strongly and cleared before re-subscribing
- [ ] Remote subscription ids detached on teardown
- [ ] Modules read from CoreData; only sync services write chain data
- [ ] `EventCenter` events carry identity, not payload state
- [ ] New event has a struct + visitor method + empty default

**Ref:** architecture/data-flow.md

## Persistence

- [ ] Repository + mapper; no direct `NSManagedObjectContext`
- [ ] Schema change ships a new model version + version enum case + `nextVersion`
- [ ] Non-inferrable change has a mapping model and policy, with a test
- [ ] Partial updates use a dedicated mapper, not fetch-modify-save
- [ ] `SettingsManager` for preferences; keystore only via `KeystoreProtocol`

**Ref:** code/data-persistence.md, code/migrations.md

## Wallets & Transactions

- [ ] Accounts resolved via `ChainAccountResponse`; "no account on chain" handled
- [ ] `MetaAccountModel` mutated only through `replacing…` helpers
- [ ] Wallet set changes go through `WalletUpdateMediator`
- [ ] `canPerformOperations` respected before offering signing actions
- [ ] Delegated wallets (proxy/multisig) supported via `ExtrinsicSenderResolution`
- [ ] Submission preceded by a `DataValidationRunner` pass
- [ ] Fees estimated for the exact call/batch being submitted
- [ ] Submitted extrinsics tracked (`submitAndWatch` or `PersistentExtrinsicService`)

**Ref:** architecture/wallets-accounts.md, architecture/transactions.md

## Feature-Area Completeness

- [ ] Staking change covers relaychain, pools, parachain, and Mythos (or says why not)
- [ ] Governance change covers both `governanceV1` and `governanceV2`
- [ ] Swap capability added as a graph edge/provider, not as a special case in the Swaps modules
- [ ] dApp capability routed through `DAppInteractionMediator`
- [ ] New notification type has extension handler + in-app handler + settings

**Ref:** architecture/staking.md, governance.md, swaps-exchange.md, dapp-walletconnect.md,
push-notifications.md

## Concurrency Model

- [ ] Operation-iOS used; no async/await, actors, or Combine introduced
- [ ] Work returned as `CompoundOperationWrapper` from a `*OperationFactory`
- [ ] Cancellable requests backed by a `CancellableCallStore`, cancelled on teardown
- [ ] Callbacks delivered on `.main` when they reach the Presenter
- [ ] An existing `OperationManagerFacade` queue is used

**Ref:** code/concurrency.md

## Cross-Cutting

- [ ] Change is confined to the stated scope; no unrelated edits
- [ ] Tests updated in the same PR (presenter, mapper, maths, migration as applicable)
- [ ] Integration tests considered for chain-interaction changes
- [ ] Files kept under ~400 lines; large additions split

## Verdict Format

```
## Architecture Review

**Verdict:** X blocking / Y major / Z minor

### Blocking
- [file:line] Description. Fix: ...

### Major
- [file:line] Description. Fix: ...

### Minor
- [file:line] Description. Suggestion: ...
```

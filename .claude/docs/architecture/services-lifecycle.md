# Services & App Lifecycle

## Launch Sequence

```
AppDelegate.didFinishLaunching
  ├─ UNUserNotificationCenter.delegate = self       (must happen before returning)
  ├─ NovaWindow + RootPresenterFactory.createPresenter(with:)
  │    └─ RootInteractor.setup()
  │         ├─ run migrators (SerialMigrator: shared settings, user DB, substrate DB)
  │         ├─ SecurityLayerService.shared.interactor      (pincode/biometry gate)
  │         ├─ ChainRegistryFacade.sharedRegistry          (starts chain + runtime sync)
  │         └─ decide onboarding vs. main flow
  ├─ presenter.loadOnLaunch()
  ├─ URLHandlingServiceFacade.shared.configure()   (after Root wired dependencies)
  └─ markAppFirstTimeLaunchIfNeeded()
```

`RootPresenterFactory` is the composition root: migrations, keychain, `SettingsManager`,
`SelectedWalletSettings`, `EventCenter`, and the chain registry closure are all resolved there.
Anything that must run before the first screen belongs in `RootInteractor`, not in `AppDelegate`.

The app skips all of this when launched with the `-UNITTEST` argument (`EnviromentVariables.isUnitTesting`).

## Service Protocols

Three protocols describe service lifetimes; pick the one that matches:

```swift
protocol ApplicationServiceProtocol {          // long-lived, started/stopped with the session
    func setup()
    func throttle()
}

protocol SyncServiceProtocol {                 // pull-based sync with retry (BaseSyncService)
    func getIsSyncing() -> Bool
    func getIsActive() -> Bool
    func syncUp(afterDelay: TimeInterval, ignoreIfSyncing: Bool)
    func stopSyncUp()
    func setup()
}

protocol PreSyncServiceProtocol {              // must complete before the main flow starts
    func setup() -> CompoundOperationWrapper<Void>
    func throttle()
}
```

- `BaseSyncService` (`Common/Services/BaseSyncService.swift`) is the base class for background
  syncers. Subclasses override `performSyncUp()` / `stopSyncUp()`; the base handles the
  `isSyncing`/`isActive` flags, the `NSLock`, and exponential retry via `ExponentialReconnection`.
- `ObservableSyncService` / `ObservableSubscriptionSyncService` add observable state on top for
  screens that show sync progress.
- `PreSyncServiceCoordinator` runs services whose result gates the UI (currently
  `AHMInfoPreSyncService`) and returns a wrapper the caller can await before showing content.

## ServiceCoordinator

`Common/Services/ServiceCoordinators/ServiceCoordinator.swift` is the aggregate of everything that
runs for the *selected wallet*. It conforms to `ApplicationServiceProtocol`, so `setup()`/`throttle()`
fan out to every child service.

Current members:

| Service                                | Purpose                                              |
|----------------------------------------|------------------------------------------------------|
| `substrateBalancesService`             | Substrate asset balance subscriptions                |
| `hydrationEvmBalancesService`          | ORML/EVM balances on Hydration                       |
| `evmAssetsService`, `evmNativeService` | ERC-20 and native EVM balances + tx history          |
| `equilibriumService`                   | Equilibrium's non-standard balance model             |
| `githubPhishingService`                | Phishing address list sync                           |
| `delegatedAccountSyncService`          | Discovers proxy/multisig wallets on chain            |
| `walletNotificationService`            | In-app notification badges for delegated wallets     |
| `syncModeUpdateService`                | Adjusts per-chain sync mode for the selected wallet  |
| `dappMediator`                         | DApp interaction (see architecture/dapp-walletconnect.md) |
| `pushNotificationsFacade`              | Push registration and wallet/topic sync              |
| `pendingMultisigSyncService`           | Pending multisig operations                          |

Three wallet-lifecycle hooks exist and must be kept consistent when adding a service:

```swift
func updateOnWalletSelectionChange()          // user switched wallet -> update(selectedMetaAccount:)
func updateOnWalletChange(for source: WalletsChangeSource)  // wallet added/edited
func updateOnWalletRemove()
```

`ServiceCoordinator.createDefault(for:)` is the factory. When you add a service:

1. Add the stored property + init parameter (**non-optional** if it always exists).
2. Wire it into `setup()` and `throttle()` — both, always.
3. Decide whether it needs `update(selectedMetaAccount:)` and add it to
   `updateOnWalletSelectionChange()`.
4. Construct it in `createDefault(for:)` using the shared facades, not new instances.

## Shared Facades & Singletons

These are the sanctioned singletons. Depend on the **protocol**, inject from the ViewFactory, and
never reach for `.shared` inside a Presenter/Interactor method body.

| Facade                                        | Provides                                     |
|-----------------------------------------------|----------------------------------------------|
| `ChainRegistryFacade.sharedRegistry`          | Chains, connections, runtime providers       |
| `SubstrateDataStorageFacade.shared`           | Blockchain-derived CoreData store            |
| `UserDataStorageFacade.shared`                | Wallets/user CoreData store                  |
| `SettingsManager.shared`                      | UserDefaults-backed settings                 |
| `SelectedWalletSettings.shared`               | Currently selected `MetaAccountModel`        |
| `OperationManagerFacade.*`                    | Named `OperationQueue`s (see code/concurrency.md) |
| `EventCenter.shared`                          | In-app event bus                             |
| `LocalizationManager.shared`                  | Current locale + change notifications        |
| `Logger.shared`                               | SwiftyBeaver-backed logger                   |
| `WalletServiceFacade.*`                       | Shared remote subscription services          |
| `AppearanceFacade.shared`                     | Icon/appearance preferences                  |
| `PushNotificationsServiceFacade.shared`       | Push registration and sync                   |
| `NovaAuthFacade.shared`                       | One installation/current bearer shared by analytics |
| `ApplicationConfig.shared`                    | Static URLs, emails, deep-link scheme        |
| `URLHandlingServiceFacade.shared`             | Deep link / universal link dispatch          |
| `AnalyticsFacadeFactory.createDefault()`      | Consent-gated analytics; owned by Root       |

`AnalyticsServiceFacade` lives in the `NovaAnalytics` package and takes an
`AnalyticsConfiguration`, so the singleton and the build-flag gating are the app's:
`AnalyticsFacadeFactory` is the only place that holds the instance. It is set up by
`RootInteractor.setup()` — after `runMigrators()` and
before `walletSettings.setup` — and deliberately *not* by `ServiceCoordinator`, which runs only
after the pincode gate. Sessions and `app_opened` must be recorded on every launch, including
one the user abandons at the pincode screen. Nothing is persisted or sent without consent.

## Per-Feature Shared State

Flows that span several screens create a "shared state" object once and pass it down through
ViewFactories rather than re-creating services per screen:

- `StakingSharedStateFactory` → `RelaychainStakingSharedState`, `NPoolsStakingSharedState`,
  `ParachainStakingSharedState`, `MythosStakingSharedState`, `RelaychainStartStakingState`
- `GovernanceSharedState` — referenda observable state, subscription factories, block time service,
  SwipeGov service
- `CrowdloanSharedState`

A shared state exposes `setup(for:)`/`throttle()`-style methods that start its per-chain services
once. Entering the flow starts them; leaving stops them. Never call `setup()` on a shared service
from an individual screen's Interactor without a matching `throttle()`.

## Configuration

- `ApplicationConfig` (`Common/Configs/ApplicationConfigs.swift`) — compile-time constants: URLs,
  support email, deep-link scheme/host, remote list endpoints, cache paths. **All new URLs and
  endpoints go here**, never inline in a module.
- `GlobalConfig` (`Common/GlobalConfig/`) — a small `Decodable` fetched at runtime
  (`multiStakingApiUrl`, `multisigsApiUrl`, `proxyApiUrl`) via `GlobalConfigProvider`.
- `CIKeys.generated.swift` — third-party API keys injected by Sourcery at build time. Never commit
  real values into source; add the key to `Scripts/inject-keys.sh` and the CI secret store.

## Hard Rules

1. **Every `setup()` has a matching `throttle()`.** Services that only start leak subscriptions and
   keep chain connections alive.
2. **Services are non-optional dependencies.** If a coordinator always needs it, don't make it `?`.
3. **Inject protocols, not concrete types**, even for singleton-backed services — this is what makes
   modules testable with Cuckoo mocks.
4. **No business logic in `AppDelegate`.** It only wires the window, the push delegate, URL
   handling, and orientation.
5. **Feature flags gate behaviour at the factory level.** Use `#if F_RELEASE` / `#if F_DEV` where the
   service is *created* (as `DelegatedAccountSyncService`'s wallet filter does), not with early
   returns inside the service's methods.

## Shared backend authentication

`NovaAuthFacade.shared` owns the one `NovaAuth` client. Global config snapshots have monotonically
increasing revisions; late old fetches cannot reactivate a previous origin. Analytics consent/erasure and wallet changes never reset this authentication owner. Host activation
authorizes ordinary later demand to bootstrap after accepted origin changes and legacy-reset repair;
activation itself creates no key and sends no auth request. This explicitly replaces the supplied
profile-3 protocol's user-driven re-creation wording at lines 511–514. Requests carry no intent.
Failed auth completes the caller operation;

Local calculations do not require a separate auth request. The package exposes a
context invalidation ID so the facade also detects a cold origin replacement/repair before
publishing its first endpoint.
Failed adoption notifies when its memory fence changed.
First activation with no prior installation does not itself invalidate a context.

Each issuance flight attempts at most one new key generation. An unusable identity is retired
and that flight fails; a later independent demand may replace it after short auth backoff.
Ordinary proof/policy refusal preserves an existing binding. Pending unknown-client probes keep
the same UUID/key within the same-boot 120-second uncertainty window and persist send backoff.
Only 429 and explicit 503 attestation_unavailable apply shared auth-origin protection; ordinary
business errors are returned to their domain. Legacy optional quotas/long-delay fields are ignored.

The memory context fence advances before persistence; a failed save cannot roll it back.
Staged writes and owed token deletion retry on activation and block admission until repaired.

Auth composition needs neither an App Group container nor a shared Keychain access group: the
bearer sits in the app's default Keychain group. A refused registration keeps the client ID and
drops only the key; background demands wait out a persisted refusal delay while user-driven
demands re-register at once. The host uses `SettingsManager.shared` set/read-back. Its cached read-back cannot establish
durable persistence or detect every refused disk write. There is no extra commit API.

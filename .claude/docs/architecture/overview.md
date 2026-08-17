# Architecture Overview

Nova Wallet iOS is a non-custodial multi-chain wallet for the Polkadot/Kusama ecosystem plus EVM
chains. It is a single Xcode project (no workspace packages) with one app target, one notification
service extension, and two test targets.

## Stack

| Area              | Choice                                                                       |
|-------------------|------------------------------------------------------------------------------|
| UI                | UIKit only, fully programmatic layout (no Storyboards except LaunchScreen)     |
| Layout            | SnapKit + `UIKit_iOS` view primitives                                         |
| Architecture      | VIPER, one module per screen/flow                                             |
| Async             | Operation-iOS (`CompoundOperationWrapper`) — **not** async/await, not Combine |
| Blockchain        | `SubstrateSdk` (substrate-sdk-ios), `web3swift`/`Web3Core` for EVM            |
| Crypto            | `NovaCrypto` (Crypto-iOS), `Keystore_iOS` for secret storage                  |
| Persistence       | CoreData via two storage facades + `SettingsManager` (UserDefaults) + Keychain |
| Resources         | R.swift (`R.color`, `R.image`, `R.string(preferredLanguages:).localizable`)   |
| Localization      | `.strings` catalogs per language + `LocalizableResource<T>`                   |
| Dependency mgmt   | Swift Package Manager, all remote (no local packages)                         |
| Codegen           | R.swift (build phase), Sourcery (CI keys), Cuckoo (test mocks, checked in)     |
| CI/CD             | GitHub Actions + fastlane (Firebase distribution, TestFlight)                 |

Deployment target iOS 16.0, Swift language version 5.0, dark-mode only UI.

## Target Map

| Target                              | Purpose                                                        |
|-------------------------------------|----------------------------------------------------------------|
| `novawallet`                        | The app                                                        |
| `NovaPushNotificationServiceExtension` | Rich/decrypted push content, own `R.generated.swift` + strings |
| `novawalletTests`                   | Unit tests, Cuckoo mocks                                       |
| `novawalletIntegrationTests`        | Tests that hit live chains/backends; not run in PR CI          |

## Source Layout

```
novawallet/
  AppDelegate.swift        # launch, URL handling, push delegate
  Common/                  # everything shared across modules
    Model/                 # domain models (ChainModel, ChainAsset, MetaAccountModel, ...)
    Services/              # long-lived services (ChainRegistry, ExtrinsicService, sync services)
    DataProvider/          # local subscription factories + Subscriber/Handler traits
    Storage/               # CoreData facades, data models, entity<->model mappers
    Network/               # JSON-RPC, HTTP operation factories, Subquery, Etherscan, ...
    Substrate/             # calls, types, coders, storage-path helpers
    Crypto/                # signing wrappers, keystore tags
    View/ ViewController/ ViewModel/  # reusable UIKit components and view models
    Protocols/             # wireframe mix-ins (*Presentable) and view protocols
    Extension/ Helpers/    # extensions and small utilities
    Validation/            # DataValidating runners and validators
    Migration/             # CoreData / UserDefaults / keystore migrations
    Configs/ GlobalConfig/ # ApplicationConfig + remote GlobalConfig
  Modules/                 # ~57 top-level VIPER feature areas
  Assets.xcassets/ Fonts/ Resources/ *.lproj/
```

`Common/` is the shared layer; `Modules/` is the feature layer. Modules may depend on `Common/`;
`Common/` must never depend on a module.

## Runtime Shape

```
AppDelegate
  └─ NovaWindow
       └─ RootPresenterFactory.createPresenter(with:)      # Modules/Root
            ├─ storage migrations + settings setup
            ├─ security/pincode gate                       # Modules/Pincode, Modules/SecurityLayer
            └─ NovaMainAppContainer                        # hosts tab bar + DApp browser widget
                 └─ MainTabBar                             # Wallet / Vote / Staking / DApps / Settings
```

- `RootPresenterFactory` is the composition root: it runs migrations, decides onboarding vs. main
  flow, and starts `ServiceCoordinator`.
- `NovaMainAppContainer` wraps the tab bar so the DApp browser can be shown as a floating widget
  above it.
- `URLHandlingServiceFacade` is configured after Root has initialised dependencies; it dispatches
  deep links and universal links.

## Major Subsystems

| Subsystem            | Entry point                                        | Doc                              |
|----------------------|----------------------------------------------------|----------------------------------|
| Chains & runtime     | `ChainRegistryFacade.sharedRegistry`               | architecture/chain-registry.md   |
| App services         | `ServiceCoordinator.createDefault(for:)`           | architecture/services-lifecycle.md |
| Balances & data      | `*LocalSubscriptionFactory` + `*Subscriber` traits | architecture/data-flow.md        |
| Wallets & signing    | `SelectedWalletSettings`, `SigningWrapperFactory`  | architecture/wallets-accounts.md |
| Transactions         | `ExtrinsicServiceFactory`, `EvmTransactionService` | architecture/transactions.md     |
| Staking              | `StakingSharedStateFactory`, `MultistakingSyncService` | architecture/staking.md      |
| Governance           | `GovernanceSharedState`                            | architecture/governance.md       |
| Swaps                | `AssetsExchangeService` + exchange graph           | architecture/swaps-exchange.md   |
| DApps                | `DAppInteractionFactory.createMediator(for:)`      | architecture/dapp-walletconnect.md |
| Push                 | `PushNotificationsServiceFacade.shared`            | architecture/push-notifications.md |

## Non-Negotiables

1. **UIKit + VIPER.** Every screen is a VIPER module; there is no SwiftUI screen architecture here
   (`import SwiftUI` appears twice in the whole app, for isolated helpers).
2. **Operation-iOS, not structured concurrency.** New async work uses `CompoundOperationWrapper`
   and the `execute(...)` helpers. There are no actors, no `AsyncStream`, and effectively no
   `async`/`await` in the app target.
3. **Dark mode only.** Never add light-mode variants or `traitCollection` branches for appearance.
4. **All chain data is chain-registry-driven.** Never hardcode node URLs, asset ids, or runtime
   assumptions in a module — go through `ChainRegistry` / `ChainAsset`.
5. **Secrets never in source.** Third-party keys are injected by Sourcery into
   `CIKeys.generated.swift` at build time from `env-vars.sh` / CI secrets.

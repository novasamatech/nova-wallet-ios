# Documentation Index

> **Lazy-load model** — load only the docs relevant to the current task.
> Read the routing table below, then `Read` specific files as needed.

## Routing Table

| If the task involves...                                        | Load                                                          |
|----------------------------------------------------------------|---------------------------------------------------------------|
| First orientation, "how is this app put together"              | architecture/overview.md                                      |
| New screen / VIPER module, module restructuring                | architecture/viper.md, code/project-layout.md                 |
| Where does this file/type belong                               | code/project-layout.md                                        |
| Chains, connections, runtime metadata, `ChainRegistry`         | architecture/chain-registry.md                                |
| App startup, `ServiceCoordinator`, background sync services    | architecture/services-lifecycle.md                            |
| Local subscriptions, data providers, `EventCenter`             | architecture/data-flow.md                                     |
| Wallets, accounts, key storage, signing, hardware wallets      | architecture/wallets-accounts.md                              |
| Extrinsics, fees, transfers, XCM, submission & tracking        | architecture/transactions.md                                  |
| Staking (relaychain, pools, parachain, Mythos), rewards        | architecture/staking.md                                       |
| Governance, referenda, delegation, SwipeGov                    | architecture/governance.md                                    |
| Swaps, asset exchange graph, Hydration, AssetHub               | architecture/swaps-exchange.md                                |
| DApp browser, JS bridge, WalletConnect                         | architecture/dapp-walletconnect.md                            |
| Push notifications, Firebase, notification extension           | architecture/push-notifications.md                            |
| Operations, `CompoundOperationWrapper`, cancellation, queues   | code/concurrency.md                                           |
| CoreData, repositories, mappers, `SettingsManager`, keystore   | code/data-persistence.md                                      |
| CoreData/UserDefaults/keystore schema changes                  | code/migrations.md                                            |
| JSON-RPC, HTTP, storage queries, runtime calls, SCALE          | code/networking.md                                            |
| UIKit views, SnapKit, styles, colors, fonts, `R.swift`         | code/ui-uikit.md                                              |
| Wireframes, presentables, deep links, modal presentation       | code/navigation.md                                            |
| Strings, `LocalizableResource`, locale-aware view models       | code/localization.md                                          |
| Errors, validation runners, logging                            | code/error-handling.md                                        |
| Naming, comments, dead code, file size                         | code/naming-and-hygiene.md                                    |
| Unit tests, integration tests, Cuckoo mocks                    | code/testing.md                                               |
| Build commands, configurations, flags, codegen, CI, fastlane   | code/build-and-tooling.md                                     |
| Reviewing a PR (architecture)                                  | review/architecture-checklist.md                              |
| Reviewing a PR (code)                                          | review/code-checklist.md                                      |
| Spec/plan agent protocol: names, rounds, escalation            | process/design-loop.md                                        |

## Glossary of Load-Bearing Terms

These terms carry specific meaning in this codebase. Use them precisely:

| Term                     | Meaning                                                                                     |
|--------------------------|---------------------------------------------------------------------------------------------|
| Module                   | VIPER feature module under `novawallet/Modules/`; a screen or flow, not an SPM package        |
| ViewFactory              | `static func createView(...)` — the only place a module is assembled and wired                |
| Wireframe                | Navigation + module-to-module transitions; conforms to `*Presentable` protocol mix-ins        |
| ViewLayout               | `UIView` subclass owning all layout; installed via `loadView()`, reached via `ViewHolder`     |
| Wrapper                  | `CompoundOperationWrapper<T>` — the unit of async work in this codebase                       |
| Local subscription       | CoreData-backed `StreamableProvider`/`DataProvider` stream consumed via a `*Subscriber` trait |
| Remote subscription      | On-chain storage subscription over WebSocket, refcounted per chain/account                    |
| Shared state             | Per-feature service bundle (`RelaychainStakingSharedState`, `GovernanceSharedState`)          |
| Meta account             | `MetaAccountModel` — a wallet; may carry per-chain accounts (`ChainAccountModel`)             |
| Delegated account        | Proxied or multisig wallet acting through another wallet's key                                |
| Chain asset              | `ChainAsset` — the (chain, asset) pair that identifies a balance/operation target             |
| Sync service             | `ApplicationServiceProtocol` (`setup()`/`throttle()`) or `BaseSyncService` background worker   |
| `F_RELEASE` / `F_DEV`    | Swift compilation flags set per build configuration in `novawallet/Configs/*.xcconfig`         |

## Reference Material

- `CLAUDE.md` — routing entry point (always loaded)
- `Templates/viper-code-layout/` — canonical VIPER module templates used by Generamba
- `Cuckoofile.toml` — the source list for generated test mocks
- `novawallet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` — resolved dependency versions
- `README.md` — public setup instructions

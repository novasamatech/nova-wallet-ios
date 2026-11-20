# Project Layout — Where Does It Belong?

One Xcode project plus two local SPM packages under `Packages/`. The structural boundaries
are `Common/` (shared) vs. `Modules/` (features) inside the app target, and the package
boundary outside it. Placing code correctly is the most common review question.

## Local Packages

| The code knows about…                                                    | It belongs in    |
|----------------------------------------------------------------------------|-------------------|
| Analytics events, the queue, consent, the uploader                         | `Packages/NovaAnalytics` |
| Shared authentication, DeviceCheck, bearer issuance                             | `Packages/NovaAuth` |

Operation combining, the `Longrun` primitives and the `CompoundOperationWrapper` conveniences
(`insertingHead`/`insertingTail`, `addDependency(wrapper:)`, `createWithResult`/`createWithError`)
come from Operation-iOS 3.x itself, for the packages and the app alike. `Longrunable` and
`AnyLongrun` are the package's; the app still keeps its own `OperationCombiningService`,
`LongrunOperation` and `Scheduler` under `novawallet/Common/`.

### Names the app shares with the packages

substrate-sdk-ios 5, Operation-iOS 3 and Foundation-iOS 1.5 export public types under names the app
already used for its own: `OperationCombiningService`, `Scheduler`, `DummySigner`,
`StorageRequestFactory`, `MetadataHashOperationFactory`, `RuntimeCoderFactory`, the storage coding
operations and more. The full list is the set of aliases in
`novawalletTests/Helper/PackageNameDisambiguation.swift`.

**Inside the app target the app's declaration shadows the package's one silently.** App code gets
the app type, package code gets the package type, and nothing warns that there are two. The
consequence to keep in mind: a fix or a behaviour change that lands in the package does not reach
the app's copy.

Rules:

1. **No new copies.** Before adding a type, check whether a package already exports the name
   (`grep` the checkouts under `SourcePackages/checkouts`). If it does, use the package type or
   pick another name.
2. **Delete a copy that has become identical** to the package's type and use the package one — this
   is how the app's `Longrun.swift` went away. A copy that differs stays until its behaviour is
   reconciled; converging the remaining ones is tracked separately, not done in passing.
3. **A shared name needs an alias in the test targets.** Test files import both the app and the
   packages, where such a name is ambiguous. Every app type that keeps a shared name gets
   `typealias X = novawallet.X` in `PackageNameDisambiguation.swift`, and the alias is removed
   together with the copy (code/testing.md).
4. **No extension member that a package already declares on the same type.** Members can't be
   aliased: two identical ones are ambiguous in the test targets, so the app's one is deleted.

Nothing in a package may reference an app type — no `ApplicationConfig`, `GlobalConfig`,
`Logger`, `UserDataStorageFacade`, `OperationManagerFacade`, `R.string` or
`ApplicationServiceProtocol`. Host dependencies arrive through `AnalyticsConfiguration` or
`NovaAuthConfiguration`. The host's `NovaAuthFacade.shared` injects the same auth owner into
analytics and Bittensor; the package owns recovery, storage and DeviceCheck. The app owns
configuration/context publication and Bittensor error presentation; `NovaAnalytics` owns
consent and normal flush scheduling, retaining auth-failed batches silently for later flushes.
Auth's only store configuration is the host-supplied Keychain service: the bearer sits under it
in the app's default Keychain access group,
and a refused registration keeps the client ID while background demands wait out a persisted
delay. Settings managers are injected
through `NovaAuthConfiguration`; set/read-back provides no durable commit acknowledgement.
Package test targets take no external test dependencies: XCTest and hand-written doubles,
never Cuckoo.

## Decision Table

| The code knows about…                                        | It belongs in                                    |
|--------------------------------------------------------------|--------------------------------------------------|
| One screen only                                              | That module's folder (`Model/`, `View/`, `ViewModel/`) |
| Several screens of one feature                               | The feature's shared folder (`Modules/Staking/Model/`, `Modules/Vote/Governance/View/`) |
| Any feature, plus chain/wallet domain types                  | `Common/` (see sub-table)                        |
| Only Substrate primitives (AccountId, SCALE, hex, metadata)  | `Common/Substrate/` — or upstream `SubstrateSdk` if truly generic |
| Only Foundation/UIKit, no domain                             | `Common/Extension/Foundation/` or `Common/Extension/UIKit/` |
| Push-payload rendering                                       | `NovaPushNotificationServiceExtension/`          |

### Inside `Common/`

| Kind of code                                        | Directory                        |
|-----------------------------------------------------|----------------------------------|
| Domain model / value type                           | `Common/Model/`                  |
| Long-lived service (`setup`/`throttle`, sync)       | `Common/Services/`               |
| Local subscription factory / subscriber trait       | `Common/DataProvider/`           |
| CoreData facade, mapper, migration mapping          | `Common/Storage/`                |
| HTTP/JSON-RPC operation factory                     | `Common/Network/`                |
| Runtime calls, storage paths, SCALE types           | `Common/Substrate/`              |
| Signing, keystore tags                              | `Common/Crypto/`                 |
| Reusable UIKit component                            | `Common/View/`                   |
| Base/container view controller                      | `Common/ViewController/`         |
| Shared view model or view model factory             | `Common/ViewModel/`              |
| Wireframe mix-in (`*Presentable`) / view protocol   | `Common/Protocols/`              |
| Validator                                           | `Common/Validation/Validators/`  |
| Small utility, cache, diffing helper                | `Common/Helpers/`                |
| Type extension                                      | `Common/Extension/<Framework>/`  |
| Storage/settings/keystore migration                 | `Common/Migration/`              |
| Static config / remote config                       | `Common/Configs/`, `Common/GlobalConfig/` |

### Inside a module

```
Modules/{Feature}/{Module}/
  {Module}ViewController.swift  ViewLayout  Presenter  Interactor  Wireframe  Protocols  ViewFactory
  Model/      module-only models, errors, small helpers
  View/       module-only UIKit components and cells
  ViewModel/  view models + factories
```

Deeper feature areas nest one more level (`Modules/Staking/NominationPools/Unstake/Confirm/…`), with
shared feature code hoisted to `Modules/Staking/Model|View|ViewModel|Services|Operations|Validation/`.

## Promotion Rules

- **One consumer → keep it local.** A helper used by a single module stays in that module, ideally as
  a `private extension` next to its user.
- **Second consumer → hoist.** When a second module needs it, move it to the feature's shared folder;
  when a third feature needs it, move it to `Common/`.
- **Don't pre-generalize.** Do not create a `Common/` abstraction for something with one call site.
- **Moving a file is a normal part of a PR** — Xcode project membership must be updated too
  (`project.pbxproj` shows up in the diff; that is expected).

## Heuristics

- *Would this make sense in `substrate-sdk-ios`?* → it is a Substrate primitive; put it in
  `Common/Substrate/` (or propose it upstream), not in a feature.
- *Does it mention `ChainModel`, `ChainAsset`, `MetaAccountModel`?* → it is app-domain: `Common/`.
- *Does it know about a screen's state or view model?* → it is module-local, regardless of size.
- *Is it a secret, URL, or environment value?* → `ApplicationConfig` / `GlobalConfig` /
  `CIKeys.generated.swift`, never inline.

## Naming by Location

| Suffix                     | Meaning                                              |
|----------------------------|------------------------------------------------------|
| `*ViewController`, `*ViewLayout`, `*Presenter`, `*Interactor`, `*Wireframe`, `*Protocols`, `*ViewFactory` | VIPER pieces |
| `*OperationFactory`        | Returns `CompoundOperationWrapper`s                   |
| `*Service` / `*SyncService`| Long-lived, `setup()`/`throttle()` or `syncUp()`      |
| `*Factory`                 | Builds objects (`ViewModelFactory`, `RepositoryFactory`) |
| `*Facade`                  | Shared entry point over a subsystem                   |
| `*SharedState`             | Flow-scoped service bundle                            |
| `*Mapper`                  | CoreData entity ↔ model                               |
| `*Subscriber` / `*Handler` | Local subscription trait / its callbacks              |
| `*Presentable`             | Wireframe mix-in                                      |
| `*ViewModel`               | View-facing data                                      |
| `*Protocol`                | Protocol (all protocols end with `Protocol`, except the `*Presentable`/`*able` traits) |

## Generated & Vendored Files — Never Edit

| File                                   | Produced by                          |
|----------------------------------------|--------------------------------------|
| `R.generated.swift` (app + extension)  | R.swift build phase                   |
| `CIKeys.generated.swift`               | Sourcery (`Scripts/inject-keys.sh`)   |
| `novawalletTests/Mocks/ModuleMocks.swift`, `CommonMocks.swift` | Cuckoo (`Cuckoofile.toml`) |
| `novawallet/GoogleService-Info.plist`  | Copied per configuration by a build phase |

## Related

- architecture/viper.md — the module shape in detail
- code/naming-and-hygiene.md — naming and file-size rules
- code/build-and-tooling.md — codegen and build phases

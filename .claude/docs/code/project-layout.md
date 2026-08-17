# Project Layout — Where Does It Belong?

One Xcode project, no local SPM packages. The only structural boundary is `Common/` (shared) vs.
`Modules/` (features). Placing code correctly is the most common review question.

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

# Data Persistence

Four stores, each with a distinct purpose. Pick the right one before writing code.

| Store                       | Facade / API                              | Holds                                       |
|-----------------------------|-------------------------------------------|---------------------------------------------|
| Substrate CoreData          | `SubstrateDataStorageFacade.shared`        | Chain-derived data: chains, balances, locks, tx history, staking dashboard, NFTs |
| User CoreData               | `UserDataStorageFacade.shared`             | Wallets, accounts, user-owned settings entities |
| UserDefaults                | `SettingsManager.shared` (`Keystore_iOS`)  | Preferences, flags, selected chain/currency  |
| Keychain                    | `Keychain` / `KeystoreProtocol`            | Secrets (see architecture/wallets-accounts.md) |

Both CoreData stores live in the shared app-group container so the notification extension can read
them. `SharedSettingsManager` exposes the subset of settings the extension needs.

## Repositories

Never touch `NSManagedObjectContext` from feature code. Go through
`StorageFacadeProtocol.createRepository(...)`, which returns a `CoreDataRepository<Model, Entity>`
from `Operation_iOS`:

```swift
let repository: CoreDataRepository<AssetBalance, CDAssetBalance> = storageFacade.createRepository(
    filter: NSPredicate.assetBalance(for: accountId, chainAssetId: chainAssetId),
    sortDescriptors: [],
    mapper: AnyCoreDataMapper(AssetBalanceMapper())
)
```

In practice you use one of the pre-built factories instead of calling the facade directly:

| Factory                     | Creates                                                          |
|-----------------------------|------------------------------------------------------------------|
| `SubstrateRepositoryFactory`| Chain storage items, balances, locks/holds/freezes, tx history, stash items, phishing, chains |
| `AccountRepositoryFactory`  | Meta accounts, managed meta accounts                              |
| `ChainRepositoryFactory`    | Chain models                                                      |
| `MultistakingRepositoryFactory` | Staking dashboard items                                       |

Repositories expose operations, not synchronous calls:

```swift
let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
let saveOperation = repository.saveOperation({ [item] }, { [] })
```

Predicates live in `NSPredicate` extensions under
`Common/Extension/Foundation/Predicate/` — add new ones there so they are reusable and testable, not
inline in an Interactor. Sort descriptors have the same treatment in
`Common/Extension/Storage/SortDescriptor+Storage.swift`.

## Mappers

Model↔entity conversion lives in `Common/Storage/EntityToModel/` as `CoreDataMapperProtocol`
implementations:

```swift
final class AssetBalanceMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = AssetBalance
    typealias CoreDataEntity = CDAssetBalance

    var entityIdentifierFieldName: String { #keyPath(CDAssetBalance.identifier) }

    func populate(entity:from:using:) throws { ... }   // model -> entity
    func transform(entity:) throws -> AssetBalance { ... }  // entity -> model
}
```

Rules:

- **`transform` must throw on corrupt data** (`CommonError.dataCorruption`), never return a
  half-filled model or a default.
- **`BigUInt` is stored as `String`.** Follow the existing convention rather than inventing a new
  encoding.
- **For a partial update, write a dedicated mapper/predicate** rather than fetch → mutate → save the
  whole model. Read-modify-write races are the main source of lost updates here.
- Types that are `Identifiable & Codable` with a `CoreDataCodable` entity can use the generic
  `CodableCoreDataMapper` — the zero-arg `createRepository()` overload picks it automatically.

## Identifiers

Models persisted through repositories conform to `Operation_iOS.Identifiable` with a stable,
deterministic `identifier`:

```swift
extension ChainAccountModel: Identifiable {
    var identifier: String { [chainId, accountId.toHex(), "\(cryptoType)"].joined(separator: "-") }
}
```

`LocalStorageKeyFactory` builds the keys used for on-chain storage items so that a remote
subscription and a local read agree. Never hand-format such a key.

## Settings (UserDefaults)

Use `SettingsManagerProtocol`, never `UserDefaults` directly. Keys are declared in a `SettingsKey`
enum and exposed as typed computed properties in `Common/Extension/SettingsExtension.swift`:

```swift
extension SettingsManagerProtocol {
    var biometryEnabled: Bool? {
        get { bool(for: SettingsKey.biometryEnabled.rawValue) }
        set { ... }
    }
}
```

Adding a setting = a `SettingsKey` case + a typed accessor. Screens observe settings changes through
`SettingsSubscriber` / `SettingsLocalSubscriptionFactory` rather than re-reading on `viewWillAppear`.

`PersistentValueSettings<T>` (e.g. `SelectedWalletSettings`, `GovernanceChainSettings`,
`CrowdloanChainSettings`) is the pattern for a single persisted value that also needs async setup
and change notification.

## Caches & Files

- `InMemoryCache` (`Common/Helpers/InMemoryCache/`) for process-lifetime caches.
- `FilesRepository` / `JsonFileRepository` for on-disk JSON (runtime metadata, chain lists).
  `ApplicationConfig.fileCachePath` is the root.
- `RuntimeFilesOperationFactory` owns runtime metadata files — do not read them directly.

## Hard Rules

1. **No direct CoreData access from modules.** Repository + mapper, always.
2. **No `UserDefaults.standard`.** `SettingsManager` only.
3. **Partial updates get their own mapper**, not fetch-modify-save.
4. **Schema changes require a migration** — see code/migrations.md. Adding an attribute without a new
   model version corrupts existing installs.
5. **Throw on corrupt persisted data.** Silent defaults hide bugs and produce wrong balances.
6. **Identifiers are deterministic and stable.** Changing an `identifier` formula is a data
   migration, not a refactor.

## Related

- architecture/data-flow.md — the provider/subscription layer built on these repositories
- code/migrations.md — versioning both CoreData models, settings, and keystore entries

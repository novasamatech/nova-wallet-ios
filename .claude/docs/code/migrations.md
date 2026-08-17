# Migrations

Migrations run at launch, before the first screen, from `RootPresenterFactory` →
`RootInteractor.setup()`. They are composed with `SerialMigrator` and executed in order:

```swift
migrators: [sharedSettingsMigrator, userDatabaseMigrator, substrateDatabaseMigrator]
```

Everything conforms to one protocol:

```swift
protocol Migrating {
    func migrate() throws
}
```

Files: `novawallet/Common/Migration/`.

## CoreData Model Versions

Two models, two version enums, both step-by-step (never a jump from v3 to v20):

| Store     | Model bundle                         | Version enum              | Naming              |
|-----------|--------------------------------------|---------------------------|---------------------|
| User      | `UserDataModel.xcdatamodeld`         | `UserStorageVersion`      | `MultiassetUserDataModelN` |
| Substrate | `SubstrateDataModel.xcdatamodeld`    | `SubstrateStorageVersion` | `SubstrateDataModelN` |

Both enums are `CaseIterable`; `current` is `allCases.last`, and each case declares its
`nextVersion`. `UserStorageMigrator` / `SubstrateStorageMigrator` walk the chain from the store's
current version to `current`, applying either an inferred mapping or an explicit
`.xcmappingmodel` from `Common/Storage/MigrationMappings/`.

### Adding a schema change

1. In Xcode, **add a new model version** to the `.xcdatamodeld` (never edit the current version in
   place — shipped installs have data in it).
2. Make it the current model version.
3. Add the matching case to `UserStorageVersion` / `SubstrateStorageVersion` with the exact model
   file name, and extend `nextVersion` for the previous case.
4. If the change is not inferrable (renames, entity splits, value transformations), add an
   `.xcmappingmodel` plus an `NSEntityMigrationPolicy` (see `SingleToMultiassetMigrationPolicy`,
   `AssetIconURLToStringMigrationPolicy`).
5. Update the mapper in `Common/Storage/EntityToModel/`.
6. Add or extend a test in `novawalletTests/Common/Migration/`.

**A schema change without a new version corrupts existing installs.** There is no "recreate the
store" fallback for the user store — it holds wallets.

## Keystore Migration

`UserStorageMigrator` carries a `KeystoreMigrator` through the CoreData migration so keychain
entries can be rewritten in the same step (this is how the v1 address-keyed
`KeystoreTag` entries became `metaId`-keyed `KeystoreTagV2` entries).

`KeystoreMigrating` buffers changes and applies them on `finalize()`:

```swift
func switchVersion() throws
func fetchKey(for identifier: String) -> Data?
func save(key: Data, for identifier: String)
func deleteKey(for identifier: String)
func finalize() throws
```

Entity migration policies reach it through `UserStorageMigratorKeys.keystoreMigrator` in the manager
user info. **Never delete a keystore entry before the migration finalizes** — a crash mid-migration
would lose the user's keys.

## Settings Migration

- `SettingsMigrator` — rewrites `SettingsManager` values during a store migration
  (`UserStorageMigratorKeys.settingsMigrator`).
- `SharedSettingsMigrator` — one-shot copy of `SharedSettingsKey` values into the app-group settings
  so the notification extension can read them. Guarded by its own `DidMigrateToAppGroups` flag.
- `SelectedLanguageMigrator` — language preference format changes.
- `UserDefaultMigrator` / `StorePathMigrator` — move the store files from the old app-local location
  to the shared app-group container.

## App-Level Migrations

`Modules/WalletMigration/` is a user-visible flow (accepting a wallet handed over from another app
install), not a launch-blocking step. Do not confuse it with the storage migrations above.

## Runtime Metadata

`RuntimeLocalMigrator` handles format changes in the cached runtime metadata files. Cached runtime
data is disposable — if the format is incompatible, drop the cache and re-sync rather than writing a
complex migration.

## Hard Rules

1. **Never modify a shipped model version.** Add a new one.
2. **Version chains are contiguous.** Every case needs a `nextVersion` entry.
3. **Custom transformations need a mapping model + policy**, and a test.
4. **Keystore changes are transactional** — buffer, then `finalize()`.
5. **Migrations must be idempotent and cheap.** They run on every cold start; guard with a flag when
   the work is one-shot (as `SharedSettingsMigrator` does).
6. **Migrations throw, they don't `fatalError`.** A failed migration must surface as an error at
   Root, not as a crash loop.

## Related

- code/data-persistence.md — repositories and mappers the migrated schema feeds
- architecture/wallets-accounts.md — keystore tags and what must never be lost

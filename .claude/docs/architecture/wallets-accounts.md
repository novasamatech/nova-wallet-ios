# Wallets, Accounts & Signing

## The Wallet Model

A "wallet" is a `MetaAccountModel` (`Common/Model/ChainRegistry/Account/MetaAccountModel.swift`):

```swift
struct MetaAccountModel: Equatable, Hashable {
    typealias Id = String

    let metaId: Id
    let name: String
    let substrateAccountId: Data?      // universal substrate account
    let substrateCryptoType: UInt8?
    let substratePublicKey: Data?
    let ethereumAddress: Data?         // universal ethereum account
    let ethereumPublicKey: Data?
    let chainAccounts: Set<ChainAccountModel>   // per-chain overrides / chain-specific accounts
    let type: MetaAccountModelType
    let multisig: DelegatedAccount.MultisigAccountModel?
}
```

- The **universal** substrate/ethereum keys apply to every chain of that ecosystem.
- A `ChainAccountModel` is a per-chain override (a different key for one chain) or the only account
  for a chain-specific wallet. It carries `proxy`/`multisig` metadata when the account is delegated.
- `MetaAccountModel` is a value type. Mutation is done with the `replacing…` helpers
  (`replacingChainAccount`, `replacingName`, `replacingMultisig`, …) — never rebuild the struct
  inline in feature code; add a `replacing…` helper if one is missing.
- `ManagedMetaAccountModel` wraps `MetaAccountModel` with ordering/selection info for lists.

### Wallet Types

`MetaAccountModelType`:

| Type             | Keys live in           | Notes                                          |
|------------------|------------------------|------------------------------------------------|
| `.secrets`       | Keychain               | Standard wallet (mnemonic / seed / JSON)       |
| `.watchOnly`     | —                      | `canPerformOperations == false`                |
| `.paritySigner`  | External device        | Signs via QR                                   |
| `.polkadotVault` | External device        | Signs via QR                                   |
| `.ledger`        | Ledger (per-chain app) | Signs via BLE/USB                              |
| `.genericLedger` | Ledger (generic app)   | One app for all substrate chains               |
| `.proxied`       | Delegate's wallet      | Acts through a proxy account                   |
| `.multisig`      | Signatory's wallet     | Acts through a multisig account                |

Two derived flags matter in feature code: `canPerformOperations` (everything except `.watchOnly`)
and `isDelegated` (`.proxied` or `.multisig`). Branch on these rather than enumerating cases when
the distinction is "can this wallet sign".

### Account Resolution

Modules almost never take a raw `MetaAccountModel` for chain work. They take a resolved response:

| Type                        | Meaning                                                   |
|-----------------------------|-----------------------------------------------------------|
| `ChainAccountResponse`      | The account this wallet uses on a specific chain           |
| `MetaChainAccountResponse`  | `ChainAccountResponse` + `metaId` + wallet name/type       |
| `MetaEthereumAccountResponse` | The wallet's EVM account                                 |

Resolve them with the helpers in `Common/Helpers/ChainAccountFetching.swift` /
`AccountFetching.swift` (e.g. `wallet.fetchMetaChainAccount(for: chain.accountRequest())`), which
correctly prefer a chain-specific account over the universal one. Do not reimplement that lookup.

A `nil` response means "this wallet has no account on this chain" — a normal state. Handle it with
`WalletNoAccountHandling` / `NoAccountSupportPresentable` instead of force-unwrapping.

## Selected Wallet

`SelectedWalletSettings.shared` (`Common/Storage/SelectedWalletSettings.swift`) is a
`PersistentValueSettings` holding the currently selected wallet. Changing it emits
`SelectedWalletSwitched` on the `EventCenter` and drives
`ServiceCoordinator.updateOnWalletSelectionChange()`.

Wallet list mutations go through `WalletUpdateMediator` (`Common/Storage/WalletsUpdateMediator.swift`),
which persists the change, keeps the selection valid, and runs `WalletStorageCleaning` to purge
dependent data (balances, settings, browser sessions) for removed wallets. **Never delete a wallet by
writing to the repository directly** — the cleaners will not run.

## Secret Storage

Secrets live in the Keychain via `Keystore_iOS` (`KeystoreProtocol`, `Keychain`). Tags are built by
`KeystoreTagV2`:

```
"<metaId>-substrateSecretKey" / "-ethereumSecretKey"
"<metaId>-entropy"
"<metaId>-substrateSeed" / "-ethereumSeed"
"<metaId>-substrateDeriv" / "-ethereumDeriv"
"<chainAccountId>…"   // via KeystoreTag+MetaId.swift for chain-specific accounts
```

`KeystoreTag` (v1) is legacy, address-keyed, and only referenced by migrations.
`KeystoreMigrator` moves entries during storage migrations — see code/migrations.md.

Rules:
- Access the keystore only through `KeystoreProtocol`; never `SecItem*` directly.
- Never log, copy into view models, or pass secrets across module boundaries. The only consumers are
  signing wrappers, export flows, and cloud backup.
- Mnemonic/seed retrieval for export goes through `MnemonicFetching` and requires
  `AuthorizationPresentable` (pincode/biometry) first.

## Signing

`SigningWrapperFactory.createSigningWrapper(for:accountResponse:)` returns a
`SigningWrapperProtocol` chosen by the wallet type:

| Wallet type                   | Wrapper                              | Behaviour                          |
|-------------------------------|--------------------------------------|------------------------------------|
| `.secrets`                    | `SigningWrapper`                     | Reads the key from the keystore     |
| `.watchOnly`                  | `NoKeysSigningWrapper`               | Always throws                       |
| `.paritySigner`/`.polkadotVault` | `ParitySignerSigningWrapper`      | Presents QR sign flow               |
| `.ledger`/`.genericLedger`    | Ledger wrappers                      | Presents device flow                |
| `.proxied`/`.multisig`        | Delegated wrappers                   | Re-signs through the delegate       |

Key points:

- Signing is **potentially interactive**. Wrappers for external signers use
  `TransactionSigningPresenting` to show UI, so the signing call must be made where a presenting
  view exists (the flow's Interactor with the wireframe's presenter injected), not from a background
  service with no UI context.
- `SignatureCreatorProtocol.sign(_:context:)` takes an `ExtrinsicSigningContext` — pass the real
  context (chain, sender resolution) instead of assuming substrate.
- Crypto is selected by `MultiassetCryptoType` (sr25519, ed25519, ecdsa, ethereumEcdsa); the default
  implementations in `SigningWrapperProtocol` handle hashing per curve (blake2b for ecdsa substrate,
  keccak256 for ethereum). Don't hash before calling them.
- For tests, use `SigningWrapperFactoryStub` / `ExtrinsicServiceStub` from `novawalletTests/Mocks/`.

## Delegated Accounts (Proxy & Multisig)

`DelegatedAccountSyncService` discovers on-chain proxies and multisigs for the user's wallets and
creates/updates the corresponding `.proxied` / `.multisig` wallets, with a `DelegatedAccount.Status`
lifecycle (new / active / revoked). `MetaAccountModel.replacingDelegatedAccountStatus(from:to:)`
transitions them.

- Universal multisigs are stored on `MetaAccountModel.multisig`; single-chain ones live on the
  `ChainAccountModel`.
- `MultisigPendingOperationsService` tracks pending multisig calls;
  `WalletNotificationService` surfaces badges for wallets needing attention.
- In `F_RELEASE` builds watch-only wallets are excluded from delegated discovery (see the
  `chainWalletFilter` in `ServiceCoordinator.createDefault`).

## Onboarding, Import & Backup

| Flow                | Module                                            |
|---------------------|---------------------------------------------------|
| Create/import       | `Modules/Onboarding`, `Modules/ImportWallet`      |
| Manual backup       | `Modules/ManualBackup`                            |
| Cloud backup (iCloud)| `Modules/CloudBackup` + `Common/Services/CloudBackup` |
| Export              | `Modules/ExportWallet`                            |
| Hardware wallets    | `Modules/Ledger`, `Modules/PolkadotVault`, `Modules/WatchOnly` |
| Wallet migration    | `Modules/WalletMigration`                         |

Cloud backup encrypts with a user password stored under `KeystoreTagV2.cloudBackupPasswordTag`;
changes to the wallet set must go through `WalletUpdateMediator` so backup and push wallet sync stay
consistent (`WalletsChangeSource.byCloudBackup`).

## Hard Rules

1. **Resolve accounts, don't assume them.** Always go through `ChainAccountResponse` resolution; a
   wallet may have no account on the chain you are working with.
2. **Never mutate `MetaAccountModel` inline.** Use/add a `replacing…` helper.
3. **Never persist wallet changes directly.** Use `WalletUpdateMediator`.
4. **Check `canPerformOperations`** before offering any signing action; watch-only must degrade to a
   read-only UI, not fail at signing time.
5. **Secrets never leave the keystore→signer path.** No secrets in logs, view models, analytics, or
   errors.
6. **Signing can require UI.** Design flows so the signing call has a presenting context and can be
   cancelled by the user.

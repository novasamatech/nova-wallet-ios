# DApps — Browser, JS Bridge, WalletConnect

`novawallet/Modules/DApp/` covers three related things: an in-app WKWebView browser, the JS bridges
that let a dApp talk to the wallet, and WalletConnect v2 for external dApps.

## Interaction Mediator

`DAppInteractionFactory.createMediator(for:)` builds `DAppInteractionMediator`, registered in
`ServiceCoordinator` as `dappMediator`. It is the single entry point for "a dApp wants something
from the wallet":

- Owns the shared `DAppStateDataSource` (wallets, chains, settings, phishing list).
- Registers transports (`DAppTransports`) — browser bridges and WalletConnect.
- Routes authorisation and signing requests to UI through `DAppInteractionPresenter`.

Any new dApp-facing capability plugs into the mediator; screens never talk to a transport directly.

## Browser

`Modules/DApp/DAppBrowser/`:

| Piece                          | Role                                                                |
|--------------------------------|---------------------------------------------------------------------|
| `DAppBrowserInteractor`        | Owns the web view state, transports, and the dApp session            |
| `DAppBrowserScriptHandler`     | Installs the injected JS and receives `WKScriptMessage`s             |
| `Transports/`                  | `DAppPolkadotExtensionTransport`, `DAppMetamaskTransport`            |
| `StateMachine/`                | Per-transport state machines: `PolkadotExtensionStates`, `MetamaskStates` |
| `Tabs/`, `WebViewPool`         | Multi-tab browsing with pooled/reused web views                      |
| `DAppBrowserWidget`            | The minimised browser presented over the tab bar by `NovaMainAppContainer` |

The **state machine per transport** is the important design point: an incoming JS message is handled
by the current state, which returns the next state plus an optional response/UI request. Add new
message types as states/transitions, not as `if` chains in the interactor.

Injected scripts and their message names live with each transport. `DAppBrowserSigningChainResolver`
maps a dApp's requested chain to a wallet account.

## Authorisation & Signing

| Module                    | Purpose                                                     |
|---------------------------|-------------------------------------------------------------|
| `DAppAuthConfirm`         | "Allow this dApp to connect" prompt                         |
| `DAppWalletAuth`          | Wallet/account selection for a dApp request                 |
| `DAppAuthSettings`, `DAppSettings` | Managing granted permissions                       |
| `DAppOperationConfirm`    | Confirm an extrinsic/EVM tx requested by a dApp             |
| `DAppTxDetails`           | Raw payload inspection for the confirm screen               |
| `DAppPhishing`            | Blocking known phishing sites                               |

`DAppOperationConfirm` decodes the requested call with the chain's runtime so the user sees a typed
call, not raw hex. Signing then goes through the normal `SigningWrapperFactory` path
(see architecture/wallets-accounts.md), including hardware wallets.

Phishing protection: `GitHubPhishingService` syncs the address list, `ApplicationConfig.phishingListURL`
/ `phishingDAppsURL` provide the sources, and `PhishingAddressValidatorFactory` is used as a
`DataValidating` in transfer flows.

## createTransaction (injected polkadot-js signer)

`pub(extrinsic.createTransaction)` hands the wallet a `TxPayloadV1` (`PolkadotExtensionTxPayload`):
the call and every transaction extension as `{id, extra, additionalSigned}` hex. The wallet answers
with the complete signed extrinsic, not a signature. PAPI calls it whenever the signer exposes it and
does not fall back to `signPayload`, so it has to work for every wallet type `signPayload` works for.

```
DAppBrowserAuthorizedState → DAppSigningType.createTransaction → DAppOperationConfirm
  DAppCreateTransactionConfirmInteractor
    DAppTxPayloadExtrinsicOperationFactory        (ExtrinsicBuilderOperationFactoryProtocol)
      DAppTxPayloadExtensionResolver              pure verification of the payload
      ExtrinsicSenderResolution                   proxy / multisig wrapping
      DAppTxPayloadSignerPolicy                   what the actual signer may sign
    ExtrinsicProxyOperationFactory                fee on the same built extrinsic
```

**The rule: nothing the wallet could not decode with its own runtime is signed.** The resolver works
only with the wallet's metadata (the bridge drops `context.metadata`):

| Step | Behaviour |
|------|-----------|
| Version | `txExtVersion` 0 or `null` → legacy v4 when the runtime supports format 4 (metadata before v16 doesn't list formats and is treated as v4), otherwise v5 with extension version 0. Non-zero → v5; needs format 5, that extension version and `VerifyMultiSignature` in its set. Otherwise `UnsupportedTxExtensionVersion` |
| Call | Decoded with the runtime, all bytes consumed, re-encoding equal to the input. The decoded call is what the details sheet shows and what delegated wallets wrap |
| Supplied extension | `extra` and `additionalSigned` decoded with the wallet's types and re-encoded to the same bytes, else `DecodeError`. `CheckGenesis`, `CheckSpecVersion`, `CheckTxVersion` and `CheckMetadataHash` must carry the wallet's own values |
| Omitted extension | Filled by the wallet for `CheckNonce`, `CheckMortality`, `CheckMetadataHash`, genesis/spec/tx version, `ChargeTransactionPayment`, `ChargeAssetTxPayment`. Any other must have a zero-sized or optional explicit part and a zero-sized implicit part, else `MissingMandatoryExtension` — the SDK builder silently leaves out an extension it has no value for |
| `VerifyMultiSignature` | Always produced by the wallet; a supplied value is ignored |
| Not in the set of the chosen version | Ignored: PAPI sends the extensions of every version |

Supplied extensions go to the builder as `RawTransactionExtension` with the coder
`ExtrinsicExtraNode` itself would pick, and the resolver asks that node to confirm the extrinsic
keeps the bytes. Unlike the `signPayload` path (`DAppExtrinsicBuilderOperationFactory`, which adds the
wallet's default `ChargeAssetTxPayment` on top of the dApp's one) a supplied payment extension is
never replaced.

Signer policy is applied to the account that actually signs, after sender resolution:

| Signer | Behaviour |
|--------|-----------|
| Secrets | v4 and v5 |
| Watch-only | the usual "no keys" sheet |
| Proxied, multisig | the call is wrapped, `CheckNonce` of the payload is replaced with the delegate's nonce |
| Polkadot Vault, Parity Signer | v4 only; v5 → `SignerUnavailable` (a v5 signature covers a hash, the device needs the payload) |
| Ledger | v4 with the wallet's `CheckMetadataHash` whenever the wallet has a hash; v5 → `SignerUnavailable` |

Failures defined by the RFC (`DAppCreateTransactionError`) are part of a *successful*
`DAppOperationResponse` (`createTransactionResult: .failure`): the dApp gets `<Name>: <details>` and
the bridge turns the name into `error.name`. A payload that fails verification is shown as an alert
on the confirmation, and both Confirm and Reject then answer the dApp with that failure. Signer
errors and user cancellation behave as in `signPayload`.

The app requests metadata v15 at most, and `RuntimeTypeRegistryFactory` rejects v16, so in production
every request resolves to v4 today. The v5 path is covered by unit tests on the Westend metadata v16
fixture with `VerifyMultiSignature` added by hand.

## DApp Catalogue

`DAppList`, `DAppSearch`, `DAppFavorites`, `DAppAddFavorite` present the curated list fetched from
`ApplicationConfig.dAppsListURL`, with favourites persisted locally.
`Modules/BrowserNavigation` coordinates opening a dApp from elsewhere in the app (deep links,
governance dApps, banners).

## WalletConnect

`Modules/DApp/WalletConnect/` wraps the `WalletConnectSwiftV2` fork
(`novasamatech/WalletConnectSwiftV2`):

- `Service/` — pairing, session lifecycle, request queue (`WalletConnectProtocols` are mocked in
  tests via Cuckoo).
- `Transport/` — adapts WalletConnect requests into the same `DAppInteractionMediator` flow the
  browser uses, so authorisation and signing UI are shared.
- `Sessions`, `SessionDetails` — user-facing session management.
- `States/` — request handling state machine, mirroring the browser transports.

The WalletConnect project id comes from `CIKeys.generated.swift` (`wcProjectId`), injected by
Sourcery.

## Hard Rules

1. **All dApp requests go through the mediator.** No transport → wireframe shortcuts.
2. **Never sign a dApp request without showing the decoded operation.** If decoding fails, surface
   the failure; do not fall back to signing opaque bytes silently.
3. **Web view state belongs to the Interactor**, not the ViewController; the browser is still a
   VIPER module.
4. **Extend the state machines** for new JS messages instead of branching inside the script handler.
5. **Respect the phishing list** in any new flow that accepts an address or URL from a dApp.
6. **Reuse pooled web views** (`WebViewPool`); creating a fresh `WKWebView` per tab regresses memory.

## Related

- architecture/services-lifecycle.md — where `dappMediator` is started/stopped
- architecture/transactions.md — how a confirmed dApp operation is submitted

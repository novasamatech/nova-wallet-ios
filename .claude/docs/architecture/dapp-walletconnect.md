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
| `Attest/`                      | App Attest based integrity checks for privileged dApp APIs           |

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

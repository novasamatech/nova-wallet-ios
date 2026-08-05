# Navigation

All navigation happens in Wireframes. Presenters express intent (`wireframe.showDetails(from: view, …)`);
they never touch `navigationController` or `present`.

## Wireframe Shape

```swift
final class SomeWireframe: SomeWireframeProtocol {
    func showDetails(from view: SomeViewProtocol?, model: Model) {
        guard let detailsView = DetailsViewFactory.createView(model: model) else { return }

        view?.controller.navigationController?.pushViewController(
            detailsView.controller,
            animated: true
        )
    }
}
```

- Views are typed as `ControllerBackedProtocol`, which exposes `.controller: UIViewController`.
- The wireframe calls the destination's `ViewFactory` — that is the only cross-module coupling
  allowed.
- A `nil` from `createView(...)` is a normal outcome: return silently or present an error, never
  force-unwrap.
- Method names are semantic (`showDetails`, `showConfirmation`, `presentAccountOptions`,
  `complete`), never `navigate`/`goTo`.

## Presentable Mix-ins

Shared presentation behaviour lives in `Common/Protocols/` as `*Presentable` protocols with default
implementations. Compose them into the wireframe protocol instead of reimplementing:

| Protocol                        | Provides                                                |
|---------------------------------|---------------------------------------------------------|
| `AlertPresentable`              | `present(viewModel:style:from:)`, simple message alerts  |
| `ErrorPresentable`              | Present an `ErrorContentConvertible` error               |
| `BaseErrorPresentable`          | Common domain error copy (fee, balance, ED)              |
| `CommonRetryable`               | "Something went wrong — Retry" alert                    |
| `FeeRetryable`                  | Fee-specific retry                                       |
| `ModalAlertPresenting`          | Transient success/failure toasts                         |
| `SharingPresentable`            | `UIActivityViewController`                               |
| `CopyPresentable` / `CopyAddressPresentable` | Copy with confirmation toast               |
| `AddressOptionsPresentable` / `ChainAddressDetailsPresentable` | Address action sheet     |
| `WebPresentable` / `BrowserOpening` | Open a URL in the in-app browser or Safari          |
| `EmailPresentable`              | Support email composer                                   |
| `AuthorizationPresentable`      | Pincode/biometry gate before a sensitive action           |
| `AccountSelectionPresentable`, `WalletChoosePresentable`, `YourWalletsPresentable` | Wallet/account pickers |
| `ActionsManagePresentable`      | Generic actions sheet                                    |
| `ExtrinsicSubmissionPresenting` | Post-submission success screen                           |
| `ScanAddressPresentable` / `AddressScanPresentable` | QR scanning                          |
| `NoAccountSupportPresentable`, `WalletNoAccountHandling` | "No account on this chain" flows  |
| `ApplicationSettingsPresentable`| Deep link into iOS Settings                              |

Add a new mix-in when two or more wireframes need the same presentation, and keep the default
implementation in `Common/Protocols/`.

## Presentation Styles

- **Push** — the default for a next step in a flow.
- **Modal picker** — `ModalPickerFactory` / `ModalNetworksFactory` build selection lists; pass a
  `ModalPickerViewControllerDelegate` and a `context`.
- **Bottom sheet** — `Common/View/BottomSheet/` + the `UIKit_iOS` modal presentation stack.
- **Modal card** — `Common/CardLayoutPresentationController/`, `ModalCardPresentationStyle`.
- **Message sheet** — `Modules/MessageSheet` for informational/confirmation sheets (also used by
  hardware-wallet signing prompts).

Use these instead of hand-rolled `UIPresentationController` subclasses.

## Flow Completion

Multi-step flows end by unwinding, not by pushing a "done" screen:

- `WalletCreationFlowCompleting`, `MainTransitionHelper`, and module-specific `complete(on:)`
  wireframe methods return the user to the right root.
- `OnLaunchActionsQueue` (`Modules/MainTabBar/`) defers actions that must run after the main UI is
  ready.

## Deep Links & URL Handling

`Common/URLHandling/`:

| Piece                          | Role                                                        |
|--------------------------------|-------------------------------------------------------------|
| `URLHandlingServiceFacade`     | Configured from `AppDelegate`; entry point for all URLs      |
| `URLHandlingService`           | Registry of handlers                                         |
| `UniversalLink/`, `InternalLinks/`, `ExternalLinks/` | Link families                        |
| `Branch/`                      | Branch.io deferred deep links                                |
| `ScreenOpenService`            | Resolves a parsed link to a screen and opens it              |
| `SecretImportService`          | Handles wallet-import URLs                                   |
| `URLLocalRouter`, `UrlHandlingAction` | The parsed action passed to the router                |

Rules:

- Deep links must be **safe before the UI exists**. Handlers queue the action and replay it once the
  main flow is ready (cold start, pincode gate, onboarding).
- Register a new link type with the facade; never parse URLs inside a module.
- Deep link scheme/host come from `ApplicationConfig` (`deepLinkScheme`, `deepLinkHost`,
  `internalUniversalLinkURL`, `externalUniversalLinkURL`).

Push notifications navigate through `PushNotificationOpenScreenFacade`, which shares the same
"wait until ready" discipline (see architecture/push-notifications.md).

## Tab Bar & Container

`NovaMainAppContainer` hosts `MainTabBar` plus the DApp browser widget. Anything that needs to appear
above or across tabs (browser widget, banners) is coordinated there, not by an individual tab.
`MainTabBarIndex` identifies tabs; `MainTransitionHelper` switches tabs programmatically.

## Hard Rules

1. **No navigation outside a Wireframe.** No `present`/`push` in a Presenter or ViewController.
2. **Wireframes create destinations via `ViewFactory`**, never by instantiating a ViewController.
3. **Semantic method names.** `showX`, `presentX`, `complete`, not `navigate`.
4. **Handle `nil` view and `nil` created module** gracefully.
5. **Deep links defer, they don't crash.** Never assume a navigation stack exists.
6. **Shared presentation goes in a `*Presentable`**, not copy-pasted between wireframes.

## Related

- architecture/viper.md — where the wireframe sits in a module
- code/error-handling.md — error presentables and retry patterns

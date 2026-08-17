# VIPER Architecture

Every screen and flow in `novawallet/Modules/` is a VIPER module. Modules are scaffolded with
Generamba from `Templates/viper-code-layout/`.

## Generating a Module

```bash
./generamba-module.sh ModuleName
```

This runs `generamba template install` then `generamba gen ModuleName viper-code-layout`, creating
files under `novawallet/Modules/` and a test stub under `novawalletTests/Modules/` (paths come from
`Rambafile`). Generamba adds the files to the Xcode project; verify the group placement afterwards
and move the folder into the right feature subdirectory if needed.

## Module Structure

```
Modules/{Feature}/{ModuleName}/
  {ModuleName}ViewController.swift   # UIViewController, ViewHolder — lifecycle + event forwarding
  {ModuleName}ViewLayout.swift       # UIView — all layout and subviews
  {ModuleName}Presenter.swift        # presentation logic, view model assembly
  {ModuleName}Interactor.swift       # business logic, subscriptions, operations
  {ModuleName}Wireframe.swift        # navigation and module transitions
  {ModuleName}Protocols.swift        # the 5 protocol contracts
  {ModuleName}ViewFactory.swift      # module assembly (the composition root of the module)
  Model/       (optional)            # module-local models, errors, helpers
  View/        (optional)            # module-local UIKit components and cells
  ViewModel/   (optional)            # view models + view model factories
```

Larger areas nest by feature: `Modules/Staking/NominationPools/Unstake/Confirm/...`,
`Modules/Vote/Governance/ReferendumVote/...`. Keep the 7-file module shape intact at the leaf level.

## Protocol Contracts

`{ModuleName}Protocols.swift` declares all five boundaries:

```swift
protocol AssetReceiveViewProtocol: ControllerBackedProtocol {
    func didReceive(networkViewModel: NetworkViewModel)          // Presenter -> View
}

protocol AssetReceivePresenterProtocol: AnyObject {
    func setup()                                                 // View -> Presenter
    func share()
}

protocol AssetReceiveInteractorInputProtocol: AnyObject {
    func setup()                                                 // Presenter -> Interactor
    func generateQRCode(size: CGSize)
}

protocol AssetReceiveInteractorOutputProtocol: AnyObject {
    func didReceive(qrCodeInfo: QRCodeInfo)                      // Interactor -> Presenter
    func didReceive(error: AssetReceiveInteractorError)
}

protocol AssetReceiveWireframeProtocol: AnyObject,
    SharingPresentable, ErrorPresentable, AlertPresentable,
    CommonRetryable, ModalAlertPresenting, CopyAddressPresentable {}
```

Conventions that hold across the codebase:

- View protocols conform to `ControllerBackedProtocol` (and `LoadableViewProtocol` when they show a
  loading state).
- Interactor→Presenter methods are always named `didReceive(...)`; errors come back as
  `didReceive(error:)` with a module-specific error enum, never as a raw `Error` when the module can
  distinguish cases.
- Wireframe protocols are assembled from `*Presentable` mix-ins in `Common/Protocols/` — that is how
  shared presentation behaviour (alerts, sharing, address options, retry) is reused. See
  code/navigation.md.

## Data Flow

```
user action → ViewController → Presenter → Interactor → operations / subscriptions
                                   ↑                            │
                              didReceive(...) ←─────────────────┘
                                   │
                            view models → ViewController → ViewLayout
```

1. **ViewController** owns lifecycle, localisation refresh, and target/action wiring. It forwards
   raw user intent to the Presenter and binds finished view models to `rootView`.
2. **Presenter** holds the module state, converts domain models into view models (usually via a
   `ViewModelFactory`), and drives the Wireframe.
3. **Interactor** performs all data work: local subscriptions, remote subscriptions, operation
   wrappers, service calls. It knows nothing about view models.
4. **Wireframe** performs navigation and presents shared UI (alerts, sheets, share sheets).

## Module Assembly — ViewFactory

The ViewFactory is the **only** place a module is constructed. It resolves shared singletons
(`ChainRegistryFacade.sharedRegistry`, `SelectedWalletSettings.shared`, `OperationManagerFacade.*`,
`LocalizationManager.shared`, `Logger.shared`), builds the four VIPER pieces and wires them:

```swift
struct AssetReceiveViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    ) -> AssetReceiveViewProtocol? {
        let interactor = AssetReceiveInteractor(...)
        let wireframe = AssetReceiveWireframe()

        let presenter = AssetReceivePresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = AssetReceiveViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
```

Rules:

- `createView` returns an optional; return `nil` when a precondition is missing (no account for the
  chain, unsupported asset type) instead of force-unwrapping.
- Wireframes are created without dependencies whenever possible; pass shared state through the
  Presenter/Interactor instead.
- Do not create services inside the Interactor. Inject them from the ViewFactory.

## Ownership & Reference Rules

```swift
final class SomePresenter {
    weak var view: SomeViewProtocol?          // weak
    let wireframe: SomeWireframeProtocol      // strong
    let interactor: SomeInteractorInputProtocol // strong
}

final class SomeInteractor {
    weak var presenter: SomeInteractorOutputProtocol?  // weak
}
```

The ViewController holds the Presenter strongly; the Presenter holds Interactor and Wireframe
strongly; back-references are weak. Never invert this.

## Hard Rules

1. **ViewController never talks to the Interactor** — always through the Presenter.
2. **Interactor never imports UIKit** and never builds view models.
3. **ViewLayout owns all layout.** The ViewController may only bind values and wire targets.
4. **ViewFactory is the only assembly point.** No `SomeInteractor()` inside a Wireframe or Presenter.
5. **Navigation lives only in the Wireframe.** Presenters call `wireframe.showX(from: view)`.
6. **Private methods go in a separate `private extension`** below the type, usually under a
   `// MARK: Private` comment.
7. **Cancel in-flight work when inputs change.** Interactors hold `CancellableCallStore`s and clear
   providers before re-subscribing (see code/concurrency.md).
8. **Localisation is refreshed, not baked in.** ViewControllers implement `setupLocalization()` and
   re-run it from `applyLocalization()`; Presenters emit `LocalizableResource`s where the string
   depends on locale (see code/localization.md).

## Shared State Between Modules

Multi-screen flows (staking, governance, crowdloans, swaps) share long-lived services through a
"shared state" object created once and passed down through ViewFactories:

- `RelaychainStakingSharedState`, `NPoolsStakingSharedState`, `ParachainStakingSharedState`,
  `MythosStakingSharedState` — built by `StakingSharedStateFactory`
- `GovernanceSharedState` — referenda observable state, subscription factories, block time service
- `CrowdloanSharedState`

A shared state owns the per-chain services (`setup()`/`throttle()`), so entering a flow starts the
services once and leaving it stops them once. Do not recreate these services per screen.

## When to Create a Module

Create one when the change adds a screen or a distinct navigable flow.

Do **not** create a module for:
- a reusable view → `Common/View/` or the feature's `View/` folder
- an alert/action sheet → use `AlertPresentable` / `ActionsManagePresentable`
- pure business logic → a service in `Common/Services/` or a `Model/` type in the feature

## Common Mistakes

- Layout code creeping into the ViewController instead of the ViewLayout.
- Interactor building `NetworkViewModel`/`BalanceViewModel` instead of returning domain models.
- Wireframe running operations or holding business state.
- Creating a new service instance per screen instead of taking it from the shared state.
- Forgetting to update `Protocols.swift` when adding a method — it is always a peer file.
- Leaving a subscription alive after the Interactor's inputs change (stale callbacks).

## Peer Files

When you touch one of these, check the others in the same change:

| Change                                   | Peer files                                        |
|------------------------------------------|---------------------------------------------------|
| New Presenter method called by the view  | `Protocols.swift`, `ViewController`               |
| New Interactor method                    | `Protocols.swift`, `Presenter`                    |
| New Interactor callback                  | `Protocols.swift`, `Presenter`, Cuckoo mock file  |
| New dependency in any layer              | `ViewFactory`, and the module's test setup        |
| New navigation entry                     | `Wireframe`, `Protocols.swift`                    |
| New protocol that tests mock             | `Cuckoofile.toml` + regenerated mocks             |

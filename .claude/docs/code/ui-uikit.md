# UI — UIKit, Layout, Styling

UIKit only, programmatic layout, dark mode only. No Storyboards (except `LaunchScreen.storyboard`),
no XIBs, no SwiftUI screens.

## ViewController ↔ ViewLayout

The ViewController installs the layout in `loadView()` and reaches it through `ViewHolder`:

```swift
final class SomeViewController: UIViewController, ViewHolder {
    typealias RootViewType = SomeViewLayout

    let presenter: SomePresenterProtocol

    init(presenter: SomePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() { view = SomeViewLayout() }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }
}

// MARK: Private

private extension SomeViewController {
    func setupLocalization() { ... }
    func setupHandlers() { ... }
}
```

`ViewHolder.rootView` is a typed accessor over `view`. The ViewController must not create subviews or
constraints — everything belongs in the ViewLayout.

## ViewLayout

```swift
final class SomeViewLayout: UIView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .title3Primary)
        view.textAlignment = .center
    }

    let containerView = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.top.equalToSuperview().inset(Constants.verticalSpacing)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }
}

extension SomeViewLayout {
    enum Constants {
        static let verticalSpacing: CGFloat = 16
    }
}
```

Conventions:

- Subviews are `let` properties built with `UIView.create { }` (`Common/Extension/UIKit/UIView+Create.swift`).
- Layout uses SnapKit (`snp.makeConstraints`).
- Magic numbers go in a nested `Constants` enum, not inline.
- Expose derived accessors (`var titleLabel: UILabel { container.valueTop }`) instead of letting the
  ViewController reach into nested views.
- `bind(viewModel:)` methods on the layout/cell keep binding logic out of the ViewController when a
  view has non-trivial state.

## Styling

**Colors** — `R.color.colorX()` only. Never `UIColor(red:…)`, never `.systemBackground`, never a hex
literal in a view. Token names describe role, not value:

`colorTextPrimary`, `colorTextSecondary`, `colorTextPositive`, `colorTextNegative`,
`colorIconPrimary`/`Secondary`/`Accent`, `colorButtonBackgroundSecondary`, `colorButtonTextAccent`,
`colorBlockBackground`, `colorContainerBackground`, `colorContainerBorder`, `colorDivider`,
`colorSecondaryScreenBackground`, `colorBottomSheetBackground`, `colorChipsBackground`, …

If a design needs a colour that has no token, add the token to the asset catalog — do not inline it.

**Fonts** — `UIFont` extensions in `Common/Extension/UIKit/UIFont+Style.swift`
(`.regularFootnote`, `.semiBoldBody`, `.h3Title`, `.boldTitle2`, `.p1Paragraph`, …), all backed by
`R.font.publicSans*`. Never call `R.font` directly in a view, and never `UIFont.systemFont`.

**Composite styles** — `UILabel.Style`, `RoundedView` styles, `TriangularedButton` styles,
`UITextView.Style`, etc. live in `Common/Extension/UIKit/Style/` and `Common/Extension/UIKit/*+Style*.swift`:

```swift
label.apply(style: .footnoteSecondary)
button.applyDefaultStyle()
```

Add a new named style next to the existing ones rather than setting `textColor`/`font` ad hoc.

**Images** — `R.image.iconX()`. Assets are in `Assets.xcassets`; appearance-dependent icons go
through `AppearanceFacade` / `IconAppearanceDepending`.

## Reusable Components

Before building a view, check:

- `Common/View/` — ~100 shared components: `DetailsTriangularedView`, `GenericMultiValueView`,
  `GenericTitleValueView`, `AmountInputView`, `AccountInputView`, `BottomSheet/`, `ErrorView`,
  `CollectionView/`, `Skeleton*`, `ShimmeringLabel`, `StackCell*`, …
- `Common/ViewController/` — base controllers and containers: bottom sheets, modal cards,
  `ScrollableContainerView`, search controllers, navigation styling.
- `UIKit_iOS` package — `RoundedView`, `TriangularedButton`, `RoundedButton`, `ImageWithTitleView`,
  `StackTableView`, and the modal presentation stack.

Generic containers are heavily used: `GenericPairValueView`, `GenericMultiValueView<T>`,
`GenericBorderedView<T>` — compose these instead of writing a bespoke `UIView` for every row.

## Lists

- `UITableView` + `UICollectionView` with reuse extensions (`UITableView+Reuse.swift`,
  `UICollectionView+Reuse.swift`) — register/dequeue through those, not with raw identifiers.
- Diffable data sources where the list is dynamic (`UICollectionViewDiffableDataSource+apply.swift`,
  `DiffableDataStore`, `DataChangesDiffCalculator`).
- Cells bind view models; no formatting, no operations, no image downloads triggered inline in
  `cellForRow`. Use `ImageViewModelProtocol` (`Common/ViewModel/Image/`) which handles
  Kingfisher/SVG loading and cancellation.
- Skeleton loading via `SkeletonLoadable` / `SkeletonRow+View` rather than spinners in cells.

## View Models

Presenters never hand domain models to the view. Build view models with a factory:

- `BalanceViewModelFactory` / `BalanceViewModelFactoryFacade` — amounts + fiat
- `NetworkViewModelFactory`, `ChainAssetViewModelFactory`, `DisplayAddressViewModelFactory`,
  `WalletSwitchViewModelFactory`, `IdentityViewModelFactory`
- `LoadableViewModelState<T>` for loading/loaded states, `GenericViewState` for empty/error/content

Locale-dependent view models are `LocalizableResource<T>` (see code/localization.md).

## Feedback & Chrome

- Haptics: `HapticPlayer` (`Common/HapticPlayer/`), not `UIImpactFeedbackGenerator` directly.
- Animations: `Common/Animation/`, `Common/Effects/`, Lottie for complex assets.
- Navigation bar styling: `Common/ViewController/NavigationController/NavigationBarStyle.swift`.
- Modal presentation: the `UIKit_iOS` modal stack plus `Common/CardLayoutPresentationController/`.

## Hard Rules

1. **No layout in the ViewController.** If you are writing `addSubview` there, move it.
2. **No literal colors, fonts, or images.** `R.color` / `UIFont` styles / `R.image` only.
3. **Dark mode only.** No `traitCollection.userInterfaceStyle` branches, no light variants.
4. **No magic numbers.** Nested `Constants` enum per layout.
5. **Reuse before building.** Check `Common/View`, `Common/ViewController`, and `UIKit_iOS` first.
6. **Cells stay dumb.** Bind a view model; do formatting in the factory.
7. **`required init?(coder:)` is `@available(*, unavailable)` + `fatalError`** — the standard shape in
   this codebase.
8. Keep files under ~400 lines (SwiftLint warns on type bodies at 400, errors at 500) — split large
   layouts into subviews.

## Related

- code/localization.md — locale-aware labels and view models
- code/navigation.md — presenting screens, sheets, and alerts

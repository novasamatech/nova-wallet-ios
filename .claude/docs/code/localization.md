# Localization

The app ships 14 languages: `en`, `es`, `fr`, `hu`, `id`, `it`, `ja`, `ko`, `pl`, `pt-PT`, `ru`,
`tr`, `vi`, `zh-Hans`. The notification service extension has its **own** copy of the same catalogs.

## Strings

Strings live in `novawallet/<lang>.lproj/Localizable.strings` (+ `Localizable.stringsdict` for
plurals) and are accessed through R.swift with an explicit language list:

```swift
let title = R.string(preferredLanguages: locale.rLanguages).localizable.walletReceiveTitleFormat(token)
```

- **Always pass `preferredLanguages:`.** The bare `R.string.localizable` form is not used here — the
  app supports in-app language switching, so the current `Locale` must be threaded through.
- `Locale.rLanguages` is `[identifier]`; `Optional<Locale>.rLanguages` yields `[]`. Both live in
  `Common/Extension/Foundation/Locale+Localization.swift`.
- Format arguments are positional in the generated API — R.swift derives the signature from the
  `%@`/`%d` placeholders in the English string.
- English (`en.lproj/Localizable.strings`) is the source of truth. Add the key there; translations
  are managed externally. Never ship a hardcoded user-visible string.

## Localizable / LocalizationManager

`LocalizationManager.shared` owns the selected locale and notifies observers on change.

ViewControllers conform to `Localizable` (from `Foundation_iOS`) by having the localization manager
injected in `init`, then implement the refresh:

```swift
final class SomeViewController: UIViewController, ViewHolder {
    init(presenter: SomePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        ...
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

private extension SomeViewController {
    func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.titleLabel.text = R.string(preferredLanguages: languages).localizable.someTitle()
    }
}
```

`selectedLocale` comes from the `Localizable` extension. `applyLocalization()` is called
automatically when the language changes — **every** screen with static copy must implement it
(there are ~330 implementations; a screen without one shows stale text after a language switch).

## LocalizableResource

Presenters must not format strings for a fixed locale. Anything locale-dependent produced by a
factory is a `LocalizableResource<T>`:

```swift
func balanceFromPrice(
    targetAssetInfo: AssetBalanceDisplayInfo,
    amount: Decimal,
    priceData: PriceData?
) -> LocalizableResource<BalanceViewModelProtocol>
```

The view resolves it at bind time:

```swift
let viewModel = balanceViewModel.value(for: selectedLocale)
```

This is why `applyLocalization()` can re-render without re-fetching data: the Presenter keeps the
`LocalizableResource` and re-resolves it.

Use `LocalizableResource` for:
- view models built in a factory
- error content (`ErrorContentConvertible.toErrorContent(for:)` takes a `Locale?`)
- anything cached across a language change

## Formatting

Numbers, dates, and balances are locale-sensitive — never use raw string interpolation:

- `AssetBalanceFormatterFactory` / `BalanceViewModelFactory` for token and fiat amounts.
- `Common/Helpers/AssetFormattingCache/`, `FormatterCache` — formatters are cached; do not construct
  `NumberFormatter` per call.
- `Currency` (`Common/Currency/`) supplies the user's fiat currency and its symbol/position.
- Dates go through the formatter helpers in `Common/Extension/Foundation/`, not
  `DateFormatter(dateFormat:)` literals.

## Plurals & Language Selection

- Plural forms belong in `Localizable.stringsdict` — do not branch on count in Swift.
- `Modules/LanguageSelection` is the in-app language picker; `Language` (`Common/Model/Language.swift`)
  and `SelectedLanguageMigrator` handle persistence and migration of the stored preference.

## Notification Extension

`NovaPushNotificationServiceExtension/<lang>.lproj/` is a **separate** catalog with its own
`R.generated.swift`. A push-facing string must be added there too, otherwise notifications fall back
to the key or to English.

## Hard Rules

1. **No hardcoded user-visible strings.** Every one goes through `R.string(preferredLanguages:)`.
2. **Always thread the locale.** Never call the string API without `preferredLanguages:`.
3. **Every screen implements `applyLocalization()`** and re-runs `setupLocalization()`.
4. **Locale-dependent factory output is `LocalizableResource<T>`.**
5. **Add new keys to `en.lproj`** (and the extension's catalog when relevant); do not edit other
   languages by hand.
6. **Use the formatter factories** for amounts, prices, and dates — never manual interpolation.

## Related

- code/ui-uikit.md — where `setupLocalization` sits in the view lifecycle
- code/error-handling.md — localized error content

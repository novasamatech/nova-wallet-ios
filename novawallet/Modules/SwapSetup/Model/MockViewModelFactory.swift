import SoraFoundation

final class MockViewModelFactory {
    func buttonState() -> ButtonState {
        .init(
            title: .init {
                R.string.localizable.swapsSetupAssetActionSelectReceive(preferredLanguages: $0.rLanguages)
            },
            enabled: false
        )
    }

    func payTitleModel(locale: Locale) -> TitleHorizontalMultiValueView.Model {
        TitleHorizontalMultiValueView.Model(
            title:
            R.string.localizable.swapsSetupAssetSelectPayTitle(preferredLanguages: locale.rLanguages),
            subtitle:
            R.string.localizable.swapsSetupAssetMax(
                preferredLanguages: locale.rLanguages
            ),
            value: "100 DOT"
        )
    }

    func payModel() -> SwapAssetInputViewModel {
        let dotImage = RemoteImageViewModel(url: URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/chains/white/Polkadot.svg")!)
        let hubImage = RemoteImageViewModel(url: URL(string: "https://parachains.info/images/parachains/1688559044_assethub.svg")!)
        return .asset(SwapsAssetViewModel(
            symbol: "DOT",
            imageViewModel: dotImage,
            hub: .init(
                name: "Polkadot Asset Hub",
                icon: hubImage
            )
        ))
    }

    func payPriceModel() -> String? {
        "$0"
    }

    func receiveTitleModel(locale: Locale) -> TitleHorizontalMultiValueView.Model {
        TitleHorizontalMultiValueView.Model(
            title:
            R.string.localizable.swapsSetupAssetSelectReceiveTitle(preferredLanguages: locale.rLanguages),
            subtitle: "",
            value: ""
        )
    }

    func receiveModel(locale: Locale) -> SwapAssetInputViewModel {
        .empty(emptyReceiveViewModel(locale: locale))
    }

    func payAmount(
        locale: Locale,
        balanceViewModelFactory: BalanceViewModelFactoryFacadeProtocol
    ) -> AmountInputViewModelProtocol {
        let targetAssetInfo = AssetBalanceDisplayInfo(
            displayPrecision: 2,
            assetPrecision: 10,
            symbol: "DOT",
            symbolValueSeparator: "",
            symbolPosition: .suffix,
            icon: nil
        )
        return balanceViewModelFactory.createBalanceInputViewModel(
            targetAssetInfo: targetAssetInfo,
            amount: nil
        ).value(for: locale)
    }

    func emptyPayViewModel(locale: Locale) -> EmptySwapsAssetViewModel {
        EmptySwapsAssetViewModel(
            imageViewModel: StaticImageViewModel(image: R.image.iconAddSwapAmount()!),
            title: R.string.localizable.swapsSetupAssetPayTitle(preferredLanguages: locale.rLanguages),
            subtitle: R.string.localizable.swapsSetupAssetSelectSubtitle(preferredLanguages: locale.rLanguages)
        )
    }

    func emptyReceiveViewModel(locale: Locale) -> EmptySwapsAssetViewModel {
        EmptySwapsAssetViewModel(
            imageViewModel: StaticImageViewModel(image: R.image.iconAddSwapAmount()!),
            title: R.string.localizable.swapsSetupAssetReceiveTitle(preferredLanguages: locale.rLanguages),
            subtitle: R.string.localizable.swapsSetupAssetSelectSubtitle(preferredLanguages: locale.rLanguages)
        )
    }
}

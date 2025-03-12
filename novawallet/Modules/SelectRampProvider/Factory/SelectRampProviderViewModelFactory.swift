import Foundation

protocol SelectRampProviderViewModelFactoryProtocol {
    func createViewModel(
        for providerType: SelectRampProvider.ProviderType,
        assetSymbol: AssetModel.Symbol,
        actions: [RampAction],
        locale: Locale
    ) -> SelectRampProvider.ViewModel
}

class SelectRampProviderViewModelFactory: SelectRampProviderViewModelFactoryProtocol {
    func createViewModel(
        for providerType: SelectRampProvider.ProviderType,
        assetSymbol: AssetModel.Symbol,
        actions: [RampAction],
        locale: Locale
    ) -> SelectRampProvider.ViewModel {
        let languages = locale.rLanguages

        let title = switch providerType {
        case .offramp:
            R.string.localizable.selectSellProviderTitle(
                assetSymbol,
                preferredLanguages: languages
            )
        case .onramp:
            R.string.localizable.selectBuyProviderTitle(
                assetSymbol,
                preferredLanguages: languages
            )
        }

        let providers = actions.map { action in
            SelectRampProvider.ViewModel.ProviderViewModel(
                id: action.url.absoluteString,
                logo: action.logo,
                descriptionText: action.descriptionText.value(for: locale),
                fiatPaymentMethods: action.fiatPaymentMethods
            )
        }

        let footerText = R.string.localizable.selectProviderDisclaimerText(preferredLanguages: languages)

        return SelectRampProvider.ViewModel(
            titleText: title,
            providers: providers,
            footerText: footerText
        )
    }
}

import Foundation

protocol SelectRampProviderViewModelFactoryProtocol {
    func createViewModel(
        for providerType: RampActionType,
        assetSymbol: AssetModel.Symbol,
        actions: [RampAction],
        locale: Locale
    ) -> SelectRampProvider.ViewModel
}

class SelectRampProviderViewModelFactory: SelectRampProviderViewModelFactoryProtocol {
    func createViewModel(
        for providerType: RampActionType,
        assetSymbol: AssetModel.Symbol,
        actions: [RampAction],
        locale: Locale
    ) -> SelectRampProvider.ViewModel {
        let languages = locale.rLanguages

        let title = switch providerType {
        case .offRamp:
            R.string.localizable.selectSellProviderTitle(
                assetSymbol,
                preferredLanguages: languages
            )
        case .onRamp:
            R.string.localizable.selectBuyProviderTitle(
                assetSymbol,
                preferredLanguages: languages
            )
        }

        let defaultPaymentMethods: [FiatPaymentMethods] = [
            .visa(R.image.visaLogo()!),
            .mastercard(R.image.mastercardLogo()!),
            .applePay(R.image.applePayLogo()!),
            .sepa(R.image.sepaLogo()!)
        ]

        let providers = actions.map { action in
            SelectRampProvider.ViewModel.ProviderViewModel(
                id: action.url.absoluteString,
                logo: action.logo,
                descriptionText: action.descriptionText.value(for: locale),
                fiatPaymentMethods: defaultPaymentMethods
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

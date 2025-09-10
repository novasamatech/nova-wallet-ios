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
            R.string(preferredLanguages: languages).localizable.selectSellProviderTitle(
                assetSymbol
            )
        case .onRamp:
            R.string(preferredLanguages: languages).localizable.selectBuyProviderTitle(
                assetSymbol
            )
        }

        let providers = actions.map { action in
            let paymentMethods: [FiatPaymentMethodViewModel] = action.paymentMethods.map { paymentMethod in
                switch paymentMethod {
                case .visa: .icon(R.image.visaLogo()!)
                case .mastercard: .icon(R.image.mastercardLogo()!)
                case .applePay: .icon(R.image.applePayLogo()!)
                case .sepa: .icon(R.image.sepaLogo()!)
                case let .others(count): .text("+\(count)")
                }
            }

            return SelectRampProvider.ViewModel.ProviderViewModel(
                id: action.displayURLString,
                logo: action.logo,
                descriptionText: action.descriptionText.value(for: locale),
                fiatPaymentMethods: paymentMethods
            )
        }

        let footerText = R.string(preferredLanguages: languages).localizable.selectProviderDisclaimerText()

        return SelectRampProvider.ViewModel(
            titleText: title,
            providers: providers,
            footerText: footerText
        )
    }
}

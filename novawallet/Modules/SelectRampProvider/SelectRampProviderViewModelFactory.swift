import Foundation

protocol SelectRampProviderViewModelFactoryProtocol {
    func createViewModel(
        for providerType: SelectRampProvider.ProviderType,
        asset: AssetModel,
        actions: [RampAction],
        locale: Locale
    ) -> SelectRampProvider.ViewModel
}

class SelectRampProviderViewModelFactory: SelectRampProviderViewModelFactoryProtocol {
    func createViewModel(
        for providerType: SelectRampProvider.ProviderType,
        asset: AssetModel,
        actions: [RampAction],
        locale: Locale
    ) -> SelectRampProvider.ViewModel {
        let languages = locale.rLanguages
        
        let title = switch providerType {
        case .offramp:
            R.string.localizable.selectSellProviderTitle(
                asset.symbol,
                preferredLanguages: languages
            )
        case .onramp:
            R.string.localizable.selectBuyProviderTitle(
                asset.symbol,
                preferredLanguages: languages
            )
        }
        
        let footerText = R.string.localizable.selectProviderDisclaimerText(preferredLanguages: languages)
        
        return SelectRampProvider.ViewModel(
            titleText: title,
            actions: actions,
            footerText: footerText
        )
    }
}

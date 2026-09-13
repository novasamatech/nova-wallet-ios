import Foundation
import Foundation_iOS

protocol TokensManageViewModelFactoryProtocol {
    func createListViewModel(from token: MultichainToken, locale: Locale) -> TokensManageViewModel
}

final class TokensManageViewModelFactory {
    let quantityFormater: LocalizableResource<NumberFormatter>
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    init(
        quantityFormater: LocalizableResource<NumberFormatter>,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    ) {
        self.quantityFormater = quantityFormater
        self.assetIconViewModelFactory = assetIconViewModelFactory
    }

    private func createSubtitle(
        from token: MultichainToken,
        locale: Locale
    ) -> String {
        let enabledInstances = token.enabledInstances()

        if enabledInstances.isEmpty || token.instances.count == enabledInstances.count {
            return R.string(preferredLanguages: locale.rLanguages).localizable.tokensManageAllSelected()
        } else if let instance = enabledInstances.first {
            if enabledInstances.count > 1 {
                let chainsCount = quantityFormater.value(for: locale).string(
                    from: NSNumber(value: enabledInstances.count - 1)
                )
                return R.string(preferredLanguages: locale.rLanguages
                ).localizable.tokensManagePartialSelected(instance.chainName, chainsCount ?? "")
            } else {
                return instance.chainName
            }
        } else {
            return ""
        }
    }
}

extension TokensManageViewModelFactory: TokensManageViewModelFactoryProtocol {
    func createListViewModel(from token: MultichainToken, locale: Locale) -> TokensManageViewModel {
        let imageViewModel = assetIconViewModelFactory.createAssetIconViewModel(for: token.icon)
        let subtitle = createSubtitle(from: token, locale: locale)

        var hasher = Hasher()
        hasher.combine(token.symbol)
        hasher.combine(token.icon)
        hasher.combine(subtitle)
        hasher.combine(token.enabled)
        let identifier = hasher.finalize()

        return .init(
            identifier: identifier,
            symbol: token.symbol,
            imageViewModel: imageViewModel,
            subtitle: subtitle,
            isOn: token.enabled
        )
    }
}

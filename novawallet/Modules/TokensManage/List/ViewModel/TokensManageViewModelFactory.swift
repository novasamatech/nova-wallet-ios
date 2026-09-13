import Foundation
import Foundation_iOS

protocol TokensManageViewModelFactoryProtocol {
    func createListViewModel(
        from token: MultichainToken,
        visibility: AssetVisibility,
        locale: Locale
    ) -> TokensManageViewModel
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
}

// MARK: Private

private extension TokensManageViewModelFactory {
    func createSubtitle(
        from token: MultichainToken,
        visibleInstances: [MultichainToken.Instance],
        locale: Locale
    ) -> String {
        guard
            let instance = visibleInstances.first,
            visibleInstances.count < token.instances.count else {
            return R.string(preferredLanguages: locale.rLanguages).localizable.tokensManageAllSelected()
        }

        guard visibleInstances.count > 1 else {
            return instance.chainName
        }

        let chainsCount = quantityFormater.value(for: locale).string(
            from: NSNumber(value: visibleInstances.count - 1)
        )

        return R.string(preferredLanguages: locale.rLanguages).localizable.tokensManagePartialSelected(
            instance.chainName,
            chainsCount ?? ""
        )
    }
}

// MARK: TokensManageViewModelFactoryProtocol

extension TokensManageViewModelFactory: TokensManageViewModelFactoryProtocol {
    func createListViewModel(
        from token: MultichainToken,
        visibility: AssetVisibility,
        locale: Locale
    ) -> TokensManageViewModel {
        let visibleInstances = token.instances.filter { visibility.isVisible($0.chainAssetId) }
        let isOn = !visibleInstances.isEmpty

        let imageViewModel = assetIconViewModelFactory.createAssetIconViewModel(for: token.icon)
        let subtitle = createSubtitle(from: token, visibleInstances: visibleInstances, locale: locale)

        var hasher = Hasher()
        hasher.combine(token.symbol)
        hasher.combine(token.icon)
        hasher.combine(subtitle)
        hasher.combine(isOn)
        let identifier = hasher.finalize()

        return .init(
            identifier: identifier,
            symbol: token.symbol,
            imageViewModel: imageViewModel,
            subtitle: subtitle,
            isOn: isOn
        )
    }
}

import Foundation
import SoraFoundation

protocol TokensManageViewModelFactoryProtocol {
    func createViewModel(from token: MultichainToken, locale: Locale) -> TokensManageViewModel
}

final class TokensManageViewModelFactory {
    let quantityFormater: LocalizableResource<NumberFormatter>

    init(quantityFormater: LocalizableResource<NumberFormatter>) {
        self.quantityFormater = quantityFormater
    }

    private func createSubtitle(
        from token: MultichainToken,
        locale: Locale
    ) -> String {
        let enabledInstances = token.enabledInstances()

        if enabledInstances.isEmpty || token.instances.count == enabledInstances.count {
            return R.string.localizable.tokensManageAllSelected(preferredLanguages: locale.rLanguages)
        } else if let instance = enabledInstances.first {
            if enabledInstances.count > 1 {
                let chainsCount = quantityFormater.value(for: locale).string(
                    from: NSNumber(value: enabledInstances.count - 1)
                )
                return R.string.localizable.tokensManagePartialSelected(
                    instance.chainName,
                    chainsCount ?? "",
                    preferredLanguages: locale.rLanguages
                )
            } else {
                return instance.chainName
            }
        } else {
            return ""
        }
    }
}

extension TokensManageViewModelFactory: TokensManageViewModelFactoryProtocol {
    func createViewModel(from token: MultichainToken, locale: Locale) -> TokensManageViewModel {
        let imageViewModel = token.icon.map { RemoteImageViewModel(url: $0) }
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

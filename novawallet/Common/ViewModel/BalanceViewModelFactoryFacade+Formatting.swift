import Foundation
import Foundation_iOS

extension BalanceViewModelFactoryFacadeProtocol {
    func rateFromValue(
        mainSymbol: String,
        targetAssetInfo: AssetBalanceDisplayInfo,
        value: Decimal
    ) -> LocalizableResource<String> {
        let targetString = amountFromValue(
            targetAssetInfo: targetAssetInfo,
            value: value
        )

        return LocalizableResource { locale in
            "1 \(mainSymbol)".estimatedEqual(to: targetString.value(for: locale))
        }
    }
}

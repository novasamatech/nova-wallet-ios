import Foundation
import SoraFoundation
import BigInt

final class BalanceViewModelFactory: PrimitiveBalanceViewModelFactory, BalanceViewModelFactoryProtocol {
    let limit: Decimal

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        limit: Decimal = Decimal.greatestFiniteMagnitude
    ) {
        self.limit = limit

        super.init(
            targetAssetInfo: targetAssetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory,
            formatterFactory: formatterFactory
        )
    }

    func createBalanceInputViewModel(
        _ amount: Decimal?
    ) -> LocalizableResource<AmountInputViewModelProtocol> {
        let localizableFormatter = formatterFactory.createInputFormatter(for: targetAssetInfo)
        let symbol = targetAssetInfo.symbol

        let currentLimit = limit

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return AmountInputViewModel(
                symbol: symbol,
                amount: amount,
                limit: currentLimit,
                formatter: formatter,
                precision: Int16(formatter.maximumFractionDigits)
            )
        }
    }

    func createAssetBalanceViewModel(
        _ amount: Decimal,
        balance: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol> {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo)
        let optLocalizablePriceFormatter = priceFormatter(for: priceData)

        let symbol = targetAssetInfo.symbol

        let iconViewModel = targetAssetInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { locale in
            let priceString: String?

            if
                let priceData = priceData,
                let localizablePriceFormatter = optLocalizablePriceFormatter,
                let rate = Decimal(string: priceData.price) {
                let targetAmount = rate * amount

                let priceFormatter = localizablePriceFormatter.value(for: locale)
                priceString = priceFormatter.stringFromDecimal(targetAmount)
            } else {
                priceString = nil
            }

            let balanceFormatter = localizableBalanceFormatter.value(for: locale)

            let balanceString: String?

            if let balance = balance {
                balanceString = balanceFormatter.stringFromDecimal(balance)
            } else {
                balanceString = nil
            }

            return AssetBalanceViewModel(
                symbol: symbol,
                balance: balanceString,
                price: priceString,
                iconViewModel: iconViewModel
            )
        }
    }
}

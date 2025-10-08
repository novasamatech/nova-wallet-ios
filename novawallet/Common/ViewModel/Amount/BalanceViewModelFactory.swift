import Foundation
import Foundation_iOS
import BigInt

final class BalanceViewModelFactory: PrimitiveBalanceViewModelFactory, BalanceViewModelFactoryProtocol {
    let limit: Decimal
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        formattingCache: AssetFormattingCacheProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory(),
        limit: Decimal = Decimal.greatestFiniteMagnitude
    ) {
        self.limit = limit
        self.assetIconViewModelFactory = assetIconViewModelFactory

        super.init(
            targetAssetInfo: targetAssetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory,
            formattingCache: formattingCache
        )
    }

    convenience init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory(),
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        limit: Decimal = Decimal.greatestFiniteMagnitude
    ) {
        self.init(
            targetAssetInfo: targetAssetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory,
            formattingCache: AssetFormattingCache(factory: formatterFactory),
            assetIconViewModelFactory: assetIconViewModelFactory,
            limit: limit
        )
    }

    func createBalanceInputViewModel(
        _ amount: Decimal?
    ) -> LocalizableResource<AmountInputViewModelProtocol> {
        let symbol = targetAssetInfo.symbol
        let currentLimit = limit

        return LocalizableResource { [weak self] locale in
            guard let self else {
                return AmountInputViewModel(
                    symbol: symbol,
                    amount: amount,
                    limit: currentLimit,
                    formatter: NumberFormatter(),
                    precision: 0
                )
            }

            let formatter = formattingCache.inputFormatter(
                for: targetAssetInfo,
                locale: locale
            )

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
        let symbol = targetAssetInfo.symbol

        let iconViewModel = assetIconViewModelFactory.createAssetIconViewModel(
            for: targetAssetInfo.icon?.getPath(),
            defaultURL: targetAssetInfo.icon?.getURL()
        )

        return LocalizableResource { [weak self] locale in
            guard let self else {
                return AssetBalanceViewModel(
                    symbol: symbol,
                    balance: nil,
                    price: nil,
                    iconViewModel: iconViewModel
                )
            }

            let priceString: String?

            if
                let priceData = priceData,
                let rate = Decimal(string: priceData.price) {
                let targetAmount = rate * amount
                let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceData.currencyId)
                priceString = formattingCache.formatPrice(
                    targetAmount,
                    info: priceAssetInfo,
                    locale: locale
                )
            } else {
                priceString = nil
            }

            let balanceString: String?

            if let balance = balance {
                balanceString = formattingCache.formatToken(
                    balance,
                    info: targetAssetInfo,
                    locale: locale
                )
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

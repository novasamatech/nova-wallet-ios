import Foundation
import Foundation_iOS
import BigInt

class PrimitiveBalanceViewModelFactory: PrimitiveBalanceViewModelFactoryProtocol {
    let targetAssetInfo: AssetBalanceDisplayInfo
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let formattingCache: AssetFormattingCacheProtocol

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        formattingCache: AssetFormattingCacheProtocol
    ) {
        self.targetAssetInfo = targetAssetInfo
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.formattingCache = formattingCache
    }

    convenience init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        formatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        let formattingCache = AssetFormattingCache(factory: formatterFactory)
        self.init(
            targetAssetInfo: targetAssetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory,
            formattingCache: formattingCache
        )
    }

    func priceFromFiatAmount(
        _ decimalValue: Decimal,
        currencyId: Int?
    ) -> LocalizableResource<String> {
        let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)

        return LocalizableResource { locale in
            self.formattingCache.formatPrice(
                decimalValue,
                info: priceAssetInfo,
                useSuffixForBigNumbers: true,
                locale: locale
            )
        }
    }

    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String> {
        guard let rate = Decimal(string: priceData.price) else {
            return LocalizableResource { _ in "" }
        }

        let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceData.currencyId)
        let targetAmount = rate * amount

        return LocalizableResource { locale in
            self.formattingCache.formatPrice(
                targetAmount,
                info: priceAssetInfo,
                useSuffixForBigNumbers: true,
                locale: locale
            )
        }
    }

    func priceFormatter(for currencyId: Int?) -> LocalizableResource<TokenFormatter> {
        let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)

        return LocalizableResource { locale in
            self.formattingCache.assetPriceFormatter(
                for: priceAssetInfo,
                locale: locale
            )
        }
    }

    func unitsFromValue(
        _ value: Decimal,
        roundingMode: NumberFormatter.RoundingMode
    ) -> LocalizableResource<String> {
        let unitsInfo = AssetBalanceDisplayInfo.units(for: targetAssetInfo.assetPrecision)

        return LocalizableResource { locale in
            self.formattingCache.formatToken(
                value,
                info: unitsInfo,
                roundingMode: roundingMode,
                useSuffixForBigNumbers: true,
                locale: locale
            )
        }
    }

    func amountFromValue(
        _ value: Decimal,
        roundingMode: NumberFormatter.RoundingMode
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            self.formattingCache.formatToken(
                value,
                info: self.targetAssetInfo,
                roundingMode: roundingMode,
                useSuffixForBigNumbers: true,
                locale: locale
            )
        }
    }

    func lockingAmountFromPrice(
        _ amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        LocalizableResource { locale in
            let amountString = self.formattingCache.formatToken(
                amount,
                info: self.targetAssetInfo,
                roundingMode: .down,
                useSuffixForBigNumbers: true,
                locale: locale
            )

            guard
                let priceData,
                let rate = Decimal(string: priceData.price)
            else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount
            let priceAssetInfo = self.priceAssetInfoFactory.createAssetBalanceDisplayInfo(
                from: priceData.currencyId
            )
            let priceString = self.formattingCache.formatPrice(
                targetAmount,
                info: priceAssetInfo,
                useSuffixForBigNumbers: true,
                locale: locale
            )

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }

    func balanceFromPrice(
        _ amount: Decimal,
        priceData: PriceData?,
        roundingMode: NumberFormatter.RoundingMode
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        LocalizableResource { locale in
            let amountString = self.formattingCache.formatToken(
                amount,
                info: self.targetAssetInfo,
                roundingMode: roundingMode,
                useSuffixForBigNumbers: true,
                locale: locale
            )

            guard
                let priceData,
                let rate = Decimal(string: priceData.price)
            else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount
            let priceAssetInfo = self.priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceData.currencyId)
            let priceString = self.formattingCache.formatPrice(
                targetAmount,
                info: priceAssetInfo,
                useSuffixForBigNumbers: true,
                locale: locale
            )

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }

    func spendingAmountFromPrice(
        _ amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        LocalizableResource { locale in
            let amountString = self.formattingCache.formatToken(
                amount,
                info: self.targetAssetInfo,
                roundingMode: .down,
                useSuffixForBigNumbers: true,
                locale: locale
            )

            guard
                let priceData,
                let rate = Decimal(string: priceData.price)
            else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount
            let priceAssetInfo = self.priceAssetInfoFactory.createAssetBalanceDisplayInfo(
                from: priceData.currencyId
            )
            let priceString = self.formattingCache.formatPrice(
                targetAmount,
                info: priceAssetInfo,
                useSuffixForBigNumbers: true,
                locale: locale
            )

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }
}

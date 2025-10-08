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

        return LocalizableResource { [weak self] locale in
            guard let self else { return "" }

            return formattingCache.formatPrice(
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

        return LocalizableResource { [weak self] locale in
            guard let self else { return "" }

            return formattingCache.formatPrice(
                targetAmount,
                info: priceAssetInfo,
                useSuffixForBigNumbers: true,
                locale: locale
            )
        }
    }

    func priceFormatter(for currencyId: Int?) -> LocalizableResource<TokenFormatter> {
        let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        return formattingCache.assetPriceFormatter(for: priceAssetInfo)
    }

    func unitsFromValue(
        _ value: Decimal,
        roundingMode: NumberFormatter.RoundingMode
    ) -> LocalizableResource<String> {
        let unitsInfo = AssetBalanceDisplayInfo.units(for: targetAssetInfo.assetPrecision)

        return LocalizableResource { [weak self] locale in
            guard let self else { return "" }

            return formattingCache.formatToken(
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
        LocalizableResource { [weak self] locale in
            guard let self else { return "" }

            return formattingCache.formatToken(
                value,
                info: targetAssetInfo,
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
        LocalizableResource { [weak self] locale in
            guard let self else {
                return BalanceViewModel(amount: "", price: nil)
            }

            let amountString = formattingCache.formatToken(
                amount,
                info: targetAssetInfo,
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
            let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(
                from: priceData.currencyId
            )
            let priceString = formattingCache.formatPrice(
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
        LocalizableResource { [weak self] locale in
            guard let self else {
                return BalanceViewModel(amount: "", price: nil)
            }

            let amountString = formattingCache.formatToken(
                amount,
                info: targetAssetInfo,
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
            let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceData.currencyId)
            let priceString = formattingCache.formatPrice(
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
        LocalizableResource { [weak self] locale in
            guard let self else {
                return BalanceViewModel(amount: "", price: nil)
            }

            let amountString = formattingCache.formatToken(
                amount,
                info: targetAssetInfo,
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
            let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(
                from: priceData.currencyId
            )
            let priceString = formattingCache.formatPrice(
                targetAmount,
                info: priceAssetInfo,
                useSuffixForBigNumbers: true,
                locale: locale
            )

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }
}

import Foundation
import Foundation_iOS
import BigInt

class PrimitiveBalanceViewModelFactory: PrimitiveBalanceViewModelFactoryProtocol {
    let targetAssetInfo: AssetBalanceDisplayInfo
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let formatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        formatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.targetAssetInfo = targetAssetInfo
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.formatterFactory = formatterFactory
    }

    func priceFromFiatAmount(
        _ decimalValue: Decimal,
        currencyId: Int?
    ) -> LocalizableResource<String> {
        let localizableFormatter = priceFormatter(for: currencyId)

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.stringFromDecimal(decimalValue) ?? ""
        }
    }

    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String> {
        guard let rate = Decimal(string: priceData.price) else {
            return LocalizableResource { _ in "" }
        }

        let localizableFormatter = priceFormatter(for: priceData.currencyId)

        let targetAmount = rate * amount

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.stringFromDecimal(targetAmount) ?? ""
        }
    }

    func priceFormatter(for currencyId: Int?) -> LocalizableResource<TokenFormatter> {
        let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        return formatterFactory.createAssetPriceFormatter(for: priceAssetInfo)
    }

    func unitsFromValue(
        _ value: Decimal,
        roundingMode: NumberFormatter.RoundingMode
    ) -> LocalizableResource<String> {
        let localizableFormatter = formatterFactory.createTokenFormatter(
            for: AssetBalanceDisplayInfo.units(for: targetAssetInfo.assetPrecision),
            roundingMode: roundingMode
        )

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.stringFromDecimal(value) ?? ""
        }
    }

    func amountFromValue(
        _ value: Decimal,
        roundingMode: NumberFormatter.RoundingMode
    ) -> LocalizableResource<String> {
        let localizableFormatter = formatterFactory.createTokenFormatter(
            for: targetAssetInfo,
            roundingMode: roundingMode
        )

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.stringFromDecimal(value) ?? ""
        }
    }

    func lockingAmountFromPrice(
        _ amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createInputTokenFormatter(for: targetAssetInfo)
        let localizablePriceFormatter = priceFormatter(for: priceData?.currencyId)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let amountString = amountFormatter.stringFromDecimal(amount) ?? ""

            guard
                let priceData = priceData,
                let rate = Decimal(string: priceData.price) else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount

            let priceFormatter = localizablePriceFormatter.value(for: locale)
            let priceString = priceFormatter.stringFromDecimal(targetAmount) ?? ""

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }

    func balanceFromPrice(
        _ amount: Decimal,
        priceData: PriceData?,
        roundingMode: NumberFormatter.RoundingMode
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createTokenFormatter(
            for: targetAssetInfo,
            roundingMode: roundingMode
        )

        let localizablePriceFormatter = priceFormatter(for: priceData?.currencyId)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let amountString = amountFormatter.stringFromDecimal(amount) ?? ""

            guard
                let priceData = priceData,
                let rate = Decimal(string: priceData.price) else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount

            let priceFormatter = localizablePriceFormatter.value(for: locale)
            let priceString = priceFormatter.stringFromDecimal(targetAmount) ?? ""

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }

    func spendingAmountFromPrice(
        _ amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createInputTokenFormatter(for: targetAssetInfo)
        let localizablePriceFormatter = priceFormatter(for: priceData?.currencyId)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let optAmountString = amountFormatter.stringFromDecimal(amount)
            let amountString = optAmountString.map { "−" + $0 } ?? ""

            guard
                let priceData = priceData,
                let rate = Decimal(string: priceData.price) else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount

            let priceFormatter = localizablePriceFormatter.value(for: locale)
            let priceString = priceFormatter.stringFromDecimal(targetAmount) ?? ""

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }
}

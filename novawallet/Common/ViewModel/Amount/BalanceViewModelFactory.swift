import Foundation
import SoraFoundation
import IrohaCrypto

import BigInt

protocol BalanceViewModelFactoryProtocol {
    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String>

    func amountFromValue(
        _ value: Decimal,
        roundingMode: NumberFormatter.RoundingMode
    ) -> LocalizableResource<String>

    func balanceFromPrice(
        _ amount: Decimal,
        priceData: PriceData?,
        roundingMode: NumberFormatter.RoundingMode
    ) -> LocalizableResource<BalanceViewModelProtocol>
    func spendingAmountFromPrice(_ amount: Decimal, priceData: PriceData?)
        -> LocalizableResource<BalanceViewModelProtocol>
    func lockingAmountFromPrice(_ amount: Decimal, priceData: PriceData?)
        -> LocalizableResource<BalanceViewModelProtocol>
    func createBalanceInputViewModel(_ amount: Decimal?) -> LocalizableResource<AmountInputViewModelProtocol>
    func createAssetBalanceViewModel(_ amount: Decimal, balance: Decimal?, priceData: PriceData?)
        -> LocalizableResource<AssetBalanceViewModelProtocol>

    func unitsFromValue(_ value: Decimal, roundingMode: NumberFormatter.RoundingMode) -> LocalizableResource<String>
}

extension BalanceViewModelFactoryProtocol {
    func balanceFromPrice(_ amount: Decimal, priceData: PriceData?) -> LocalizableResource<BalanceViewModelProtocol> {
        balanceFromPrice(amount, priceData: priceData, roundingMode: .down)
    }

    func amountFromValue(_ value: Decimal) -> LocalizableResource<String> {
        amountFromValue(value, roundingMode: .down)
    }

    func unitsFromValue(_ value: Decimal) -> LocalizableResource<String> {
        unitsFromValue(value, roundingMode: .down)
    }

    func balanceWithPriceIfPossible(
        amount: BigUInt?,
        priceData: PriceData?,
        chainAsset: ChainAsset
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        .init { locale in
            let precision = chainAsset.assetDisplayInfo.assetPrecision
            guard let amountDecimal = Decimal.fromSubstrateAmount(amount ?? 0, precision: precision) else {
                return BalanceViewModel(amount: "", price: nil)
            }
            let balance = balanceFromPrice(amountDecimal, priceData: priceData).value(for: locale)
            if balance.price != nil, let amount = amount, amount > 0 {
                return balance
            } else {
                return BalanceViewModel(amount: balance.amount, price: nil)
            }
        }
    }
}

final class BalanceViewModelFactory: BalanceViewModelFactoryProtocol {
    let targetAssetInfo: AssetBalanceDisplayInfo
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let limit: Decimal

    private let formatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        limit: Decimal = Decimal.greatestFiniteMagnitude
    ) {
        self.targetAssetInfo = targetAssetInfo
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.formatterFactory = formatterFactory
        self.limit = limit
    }

    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String> {
        guard let rate = Decimal(string: priceData.price),
              let localizableFormatter = priceFormatter(for: priceData) else {
            return LocalizableResource { _ in "" }
        }

        let targetAmount = rate * amount

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.stringFromDecimal(targetAmount) ?? ""
        }
    }

    private func priceFormatter(for priceData: PriceData?) -> LocalizableResource<TokenFormatter>? {
        guard let priceData = priceData else {
            return nil
        }

        let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceData.currencyId)
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
        let optLocalizablePriceFormatter = priceFormatter(for: priceData)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let amountString = amountFormatter.stringFromDecimal(amount) ?? ""

            guard
                let priceData = priceData,
                let localizablePriceFormatter = optLocalizablePriceFormatter,
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

        let optLocalizablePriceFormatter = priceFormatter(for: priceData)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let amountString = amountFormatter.stringFromDecimal(amount) ?? ""

            guard
                let priceData = priceData,
                let localizablePriceFormatter = optLocalizablePriceFormatter,
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
    )
        -> LocalizableResource<BalanceViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createInputTokenFormatter(for: targetAssetInfo)
        let optLocalizablePriceFormatter = priceFormatter(for: priceData)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let optAmountString = amountFormatter.stringFromDecimal(amount)
            let amountString = optAmountString.map { "−" + $0 } ?? ""

            guard
                let priceData = priceData,
                let localizablePriceFormatter = optLocalizablePriceFormatter,
                let rate = Decimal(string: priceData.price) else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount

            let priceFormatter = localizablePriceFormatter.value(for: locale)
            let priceString = priceFormatter.stringFromDecimal(targetAmount) ?? ""

            return BalanceViewModel(amount: amountString, price: priceString)
        }
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

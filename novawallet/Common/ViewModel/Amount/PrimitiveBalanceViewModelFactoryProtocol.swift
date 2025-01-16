import Foundation
import Foundation_iOS
import BigInt

protocol PrimitiveBalanceViewModelFactoryProtocol {
    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String>

    func priceFromFiatAmount(
        _ decimalValue: Decimal,
        currencyId: Int?
    ) -> LocalizableResource<String>

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

    func unitsFromValue(_ value: Decimal, roundingMode: NumberFormatter.RoundingMode) -> LocalizableResource<String>
}

extension PrimitiveBalanceViewModelFactoryProtocol {
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

import Foundation
import Foundation_iOS

@testable import novawallet

struct StubBalanceViewModelFactory: BalanceViewModelFactoryProtocol {
    func priceFromFiatAmount(
        _: Decimal,
        currencyId _: Int?
    ) -> LocalizableResource<String> {
        LocalizableResource { _ in
            "$100"
        }
    }

    func priceFromAmount(_: Decimal, priceData _: PriceData) -> LocalizableResource<String> {
        LocalizableResource { _ in
            "$100"
        }
    }

    func amountFromValue(_: Decimal, roundingMode _: NumberFormatter.RoundingMode) -> LocalizableResource<String> {
        LocalizableResource { _ in
            "$100"
        }
    }

    func unitsFromValue(_: Decimal, roundingMode _: NumberFormatter.RoundingMode) -> LocalizableResource<String> {
        LocalizableResource { _ in
            "100"
        }
    }

    func balanceFromPrice(
        _ amount: Decimal,
        priceData: PriceData?,
        roundingMode _: NumberFormatter.RoundingMode
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        LocalizableResource { _ in
            BalanceViewModel(amount: amount.description, price: priceData?.price.description)
        }
    }

    func lockingAmountFromPrice(
        _ amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        LocalizableResource { _ in
            BalanceViewModel(amount: amount.description, price: priceData?.price.description)
        }
    }

    func spendingAmountFromPrice(
        _ amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        LocalizableResource { _ in
            BalanceViewModel(amount: amount.description, price: priceData?.price.description)
        }
    }

    func createBalanceInputViewModel(_ amount: Decimal?) -> LocalizableResource<AmountInputViewModelProtocol> {
        LocalizableResource { _ in
            AmountInputViewModel(symbol: "KSM", amount: amount, limit: 0, formatter: NumberFormatter())
        }
    }

    func createAssetBalanceViewModel(_: Decimal, balance: Decimal?, priceData: PriceData?) -> LocalizableResource<AssetBalanceViewModelProtocol> {
        LocalizableResource { _ in
            AssetBalanceViewModel(
                symbol: "KSM",
                balance: balance?.description,
                price: priceData?.price.description,
                iconViewModel: nil
            )
        }
    }
}

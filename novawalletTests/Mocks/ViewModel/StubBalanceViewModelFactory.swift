import Foundation
import Foundation_iOS

@testable import novawallet

struct StubBalanceViewModelFactory: BalanceViewModelFactoryProtocol {
    func priceFromFiatAmount(
        _ decimalValue: Decimal,
        currencyId: Int?
    ) -> LocalizableResource<String> {
        LocalizableResource { _ in
            "$100"
        }
    }
    
    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String> {
        LocalizableResource { _ in
            "$100"
        }
    }

    func amountFromValue(_ value: Decimal, roundingMode: NumberFormatter.RoundingMode) -> LocalizableResource<String> {
        LocalizableResource { _ in
            "$100"
        }
    }
    
    func unitsFromValue(_ value: Decimal, roundingMode: NumberFormatter.RoundingMode) -> LocalizableResource<String> {
        LocalizableResource { _ in
            "100"
        }
    }

    func balanceFromPrice(
        _ amount: Decimal,
        priceData: PriceData?,
        roundingMode: NumberFormatter.RoundingMode
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

    func createAssetBalanceViewModel(_ amount: Decimal, balance: Decimal?, priceData: PriceData?) -> LocalizableResource<AssetBalanceViewModelProtocol> {
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

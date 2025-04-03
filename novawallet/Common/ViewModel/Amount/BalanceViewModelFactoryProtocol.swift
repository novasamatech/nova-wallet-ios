import Foundation
import Foundation_iOS

protocol BalanceViewModelFactoryProtocol: PrimitiveBalanceViewModelFactoryProtocol {
    func createBalanceInputViewModel(_ amount: Decimal?) -> LocalizableResource<AmountInputViewModelProtocol>

    func createAssetBalanceViewModel(
        _ amount: Decimal,
        balance: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>
}

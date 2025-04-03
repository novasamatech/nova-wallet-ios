import Foundation_iOS

struct AssetDetailsLocksViewModel {
    let balanceContext: BalanceContext
    let amountFormatter: LocalizableResource<TokenFormatter>
    let priceFormatter: LocalizableResource<TokenFormatter>
    let precision: Int16
}

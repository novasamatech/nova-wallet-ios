import Foundation

struct AssetExchangeCommission: Equatable {
    let chargingOperationIndex: Int

    let asset: ChainAssetId

    let estimatedAmount: Balance

    let beneficiary: AccountId

    let rate: BigRational
}

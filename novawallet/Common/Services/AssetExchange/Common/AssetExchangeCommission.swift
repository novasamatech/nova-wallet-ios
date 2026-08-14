import Foundation

struct AssetExchangeCommission: Equatable {
    let chargingOperationIndex: Int

    let asset: ChainAssetId

    let amount: Balance

    let beneficiary: AccountId
}

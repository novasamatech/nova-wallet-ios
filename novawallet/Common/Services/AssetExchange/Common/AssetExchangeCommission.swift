import Foundation

struct AssetExchangeCommission: Equatable {
    let chargingEdgeIndex: Int

    let asset: ChainAssetId

    let amount: Balance

    let beneficiary: AccountId
}

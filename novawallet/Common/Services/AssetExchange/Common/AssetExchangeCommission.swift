import Foundation

struct AssetExchangeCommission: Equatable {
    let chargingOperationIndex: Int

    let asset: ChainAssetId

    let estimatedAmount: Balance

    let minimumChargeableAmount: Balance

    let beneficiary: AccountId

    let rateOfGross: BigRational
}

import Foundation

struct AssetExchangeCommission: Equatable {
    let chargingOperationIndex: Int

    let asset: ChainAssetId

    let estimatedAmount: Balance

    let beneficiary: AccountId

    /// Share of the operation's gross output taken as commission. Consumers apply this to the pool
    /// output, never to the net amount — see AssetExchangeCommissionConstants.rate for the advertised figure.
    let rateOfGross: BigRational
}

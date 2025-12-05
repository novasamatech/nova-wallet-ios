import Foundation

struct GiftSetupIssueCheckParams {
    let chainAsset: ChainAsset
    let enteredAmount: Decimal?
    let assetBalance: AssetBalance?
    let assetExistence: AssetBalanceExistence?
    let fee: ExtrinsicFeeProtocol?
}

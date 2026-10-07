import Foundation

struct SubtensorClaimRewardsViewModelInput {
    let preview: SubtensorRootClaimPreview
    let validatorName: String
    let rootStake: Balance?
    let unlockInterval: UInt64?
    let otherClaimableCount: Int
    let price: PriceData?
    let fee: ExtrinsicFeeProtocol?
    let signing: SubtensorOperationGate.Verdict
    let isNothingToClaim: Bool
}

struct SubtensorClaimRewardsViewModel {
    let amount: BalanceViewModelProtocol
    let networkFee: BalanceViewModelProtocol?
    let stakeAfter: String?
    let notice: String
    let signingHint: String?
    let isActionEnabled: Bool
}

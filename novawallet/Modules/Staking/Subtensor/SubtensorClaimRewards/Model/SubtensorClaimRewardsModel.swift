import Foundation

struct SubtensorClaimRewardsModel {
    let account: MetaChainAccountResponse
    let validator: SubtensorConfirmValidator
    let shownPreview: SubtensorRootClaimPreview
    let minimumClaim: Balance
}

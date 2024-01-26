import Foundation
import BigInt

struct GovernanceDelegateValidatingParams {
    let assetBalance: AssetBalance?
    let newDelegation: GovernanceNewDelegation?
    let fee: ExtrinsicFeeProtocol?
    let votes: ReferendumAccountVotingDistribution?
    let assetInfo: AssetBalanceDisplayInfo
    let selfAccountId: AccountId
}

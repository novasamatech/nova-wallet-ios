import Foundation

struct StakingRewardInfoChanged: EventProtocol {
    let chainId: ChainModel.Id

    func accept(visitor: EventVisitorProtocol) {
        visitor.processStakingRewardsInfoChanged(event: self)
    }
}

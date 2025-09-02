import Foundation
import BigInt

protocol StakingRewardsLocalHandler {
    func handleTotalReward(
        result: Result<TotalRewardItem, Error>,
        for address: AccountAddress,
        api: LocalChainExternalApi
    )
}

extension StakingRewardsLocalHandler {
    func handleTotalReward(
        result _: Result<TotalRewardItem, Error>,
        for _: AccountAddress,
        api _: LocalChainExternalApi
    ) {}
}

import Foundation
import BigInt

protocol MythosStakingLocalStorageHandler {
    func handleMinStake(
        result: Result<Balance?, Error>,
        chainId: ChainModel.Id
    )

    func handleCurrentSession(
        result: Result<SessionIndex?, Error>,
        chainId: ChainModel.Id
    )

    func handleUserStake(
        result: Result<MythosStakingPallet.UserStake?, Error>,
        chainId: ChainModel.Id,
        accountId: AccountId
    )

    func handleReleaseQueue(
        result: Result<MythosStakingPallet.ReleaseQueue?, Error>,
        chainId: ChainModel.Id,
        accountId: AccountId
    )

    func handleAutoCompound(
        result: Result<Percent?, Error>,
        chainId: ChainModel.Id,
        accountId: AccountId
    )

    func handleCollatorRewardsPercentage(
        result: Result<Percent?, Error>,
        chainId: ChainModel.Id
    )

    func handleExtraReward(
        result: Result<Balance?, Error>,
        chainId: ChainModel.Id
    )
}

extension MythosStakingLocalStorageHandler {
    func handleMinStake(
        result _: Result<Balance?, Error>,
        chainId _: ChainModel.Id
    ) {}

    func handleCurrentSession(
        result _: Result<SessionIndex?, Error>,
        chainId _: ChainModel.Id
    ) {}

    func handleUserStake(
        result _: Result<MythosStakingPallet.UserStake?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {}

    func handleReleaseQueue(
        result _: Result<MythosStakingPallet.ReleaseQueue?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {}

    func handleCollatorRewardsPercentage(
        result _: Result<Percent?, Error>,
        chainId _: ChainModel.Id
    ) {}

    func handleExtraReward(
        result _: Result<Balance?, Error>,
        chainId _: ChainModel.Id
    ) {}

    func handleAutoCompound(
        result _: Result<Percent?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {}
}

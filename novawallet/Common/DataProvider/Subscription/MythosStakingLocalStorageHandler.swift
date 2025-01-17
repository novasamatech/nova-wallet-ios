import Foundation

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
}

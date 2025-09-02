import Foundation

class MythosStakingBaseState: MythosStakingStateProtocol {
    weak var stateMachine: MythosStakingStateMachineProtocol?

    private(set) var commonData: MythosStakingCommonData

    init(
        stateMachine: MythosStakingStateMachineProtocol?,
        commonData: MythosStakingCommonData
    ) {
        self.stateMachine = stateMachine
        self.commonData = commonData
    }

    func accept(visitor _: MythosStakingStateVisitorProtocol) {}

    func process(chainAsset: ChainAsset?) {
        if chainAsset != commonData.chainAsset {
            let commonData = MythosStakingCommonData
                .empty
                .byReplacing(chainAsset: chainAsset)

            let nextState = MythosStakingInitState(
                stateMachine: stateMachine,
                commonData: commonData
            )

            stateMachine?.transit(to: nextState)
        }
    }

    func process(account: MetaChainAccountResponse?) {
        let commonData = commonData.byReplacing(account: account)

        let nextState = MythosStakingInitState(
            stateMachine: stateMachine,
            commonData: commonData
        )

        stateMachine?.transit(to: nextState)
    }

    func process(balance: AssetBalance?) {
        commonData = commonData.byReplacing(balance: balance)

        stateMachine?.transit(to: self)
    }

    func process(price: PriceData?) {
        commonData = commonData.byReplacing(price: price)

        stateMachine?.transit(to: self)
    }

    func process(collatorsInfo: MythosSessionCollators?) {
        commonData = commonData.byReplacing(collatorsInfo: collatorsInfo)

        stateMachine?.transit(to: self)
    }

    func process(stakingDetailsState _: MythosStakingDetailsState) {}

    func process(frozenBalance _: MythosStakingFrozenBalance?) {}

    func process(releaseQueue: MythosStakingPallet.ReleaseQueue?) {
        commonData = commonData.byReplacing(releaseQueue: releaseQueue)

        stateMachine?.transit(to: self)
    }

    func process(totalReward: TotalRewardItem?) {
        commonData = commonData.byReplacing(totalReward: totalReward)

        stateMachine?.transit(to: self)
    }

    func process(totalRewardFilter: StakingRewardFiltersPeriod?) {
        commonData = commonData.byReplacing(totalRewardFilter: totalRewardFilter)

        stateMachine?.transit(to: self)
    }

    func process(claimableRewards: MythosStakingClaimableRewards?) {
        commonData = commonData.byReplacing(claimableRewards: claimableRewards)

        stateMachine?.transit(to: self)
    }

    func process(blockNumber: BlockNumber) {
        commonData = commonData.byReplacing(blockNumber: blockNumber)

        stateMachine?.transit(to: self)
    }

    func process(duration: MythosStakingDuration) {
        commonData = commonData.byReplacing(duration: duration)

        stateMachine?.transit(to: self)
    }

    func process(networkInfo: MythosStakingNetworkInfo) {
        commonData = commonData.byReplacing(networkInfo: networkInfo)

        stateMachine?.transit(to: self)
    }
}

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

    func process(stakingDuration: MythosStakingDuration?) {
        commonData = commonData.byReplacing(stakingDuration: stakingDuration)

        stateMachine?.transit(to: self)
    }

    func process(collatorsInfo: MythosSessionCollators?) {
        commonData = commonData.byReplacing(collatorsInfo: collatorsInfo)

        stateMachine?.transit(to: self)
    }

    func process(calculatorEngine: CollatorStakingRewardCalculatorEngineProtocol?) {
        commonData = commonData.byReplacing(calculatorEngine: calculatorEngine)

        stateMachine?.transit(to: self)
    }

    func process(stakingDetails _: MythosStakingDetails?) {}

    func process(frozenBalance _: MythosStakingFrozenBalance?) {}

    func process(blockNumber: BlockNumber?) {
        commonData = commonData.byReplacing(blockNumber: blockNumber)

        stateMachine?.transit(to: self)
    }

    func process(currentSession: SessionIndex?) {
        commonData = commonData.byReplacing(currentSession: currentSession)

        stateMachine?.transit(to: self)
    }

    func process(totalReward: TotalRewardItem?) {
        commonData = commonData.byReplacing(totalReward: totalReward)

        stateMachine?.transit(to: self)
    }

    func process(claimableRewards: MythosStakingClaimableRewards?) {
        commonData = commonData.byReplacing(claimableRewards: claimableRewards)

        stateMachine?.transit(to: self)
    }
}

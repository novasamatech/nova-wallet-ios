import Foundation

class SubtensorStakingBaseState: SubtensorStakingStateProtocol {
    weak var stateMachine: SubtensorStakingStateMachineProtocol?

    private(set) var commonData: SubtensorStakingCommonData

    init(
        stateMachine: SubtensorStakingStateMachineProtocol?,
        commonData: SubtensorStakingCommonData
    ) {
        self.stateMachine = stateMachine
        self.commonData = commonData
    }

    func accept(visitor _: SubtensorStakingStateVisitorProtocol) {}

    func process(account: MetaChainAccountResponse?) {
        let commonData = commonData.byReplacing(account: account)

        let nextState = SubtensorStakingInitState(
            stateMachine: stateMachine,
            commonData: commonData
        )

        stateMachine?.transit(to: nextState)
    }

    func process(chainAsset: ChainAsset?) {
        if chainAsset != commonData.chainAsset {
            let commonData = SubtensorStakingCommonData
                .empty
                .byReplacing(chainAsset: chainAsset)

            let nextState = SubtensorStakingInitState(
                stateMachine: stateMachine,
                commonData: commonData
            )

            stateMachine?.transit(to: nextState)
        }
    }

    func process(balance: AssetBalance?) {
        commonData = commonData.byReplacing(balance: balance)

        stateMachine?.transit(to: self)
    }

    func process(price: PriceData?) {
        commonData = commonData.byReplacing(price: price)

        stateMachine?.transit(to: self)
    }

    func process(positionsState: Multistaking.SubtensorStakingState?) {
        let nextState: SubtensorStakingStateProtocol

        if let positionsState {
            if positionsState.hasActiveStaking {
                nextState = SubtensorStakingStakedState(
                    stateMachine: stateMachine,
                    commonData: commonData,
                    stakingState: positionsState
                )
            } else {
                nextState = SubtensorStakingNotStakedState(
                    stateMachine: stateMachine,
                    commonData: commonData
                )
            }
        } else {
            nextState = SubtensorStakingInitState(
                stateMachine: stateMachine,
                commonData: commonData
            )
        }

        stateMachine?.transit(to: nextState)
    }

    func process(claimable: SubtensorRootClaimable?) {
        commonData = commonData.byReplacing(claimable: claimable)

        stateMachine?.transit(to: self)
    }

    func process(delegates: [SubtensorDelegate]?) {
        commonData = commonData.byReplacing(delegates: delegates)

        stateMachine?.transit(to: self)
    }

    func process(subnetsInfo: SubtensorSubnetsInfo?) {
        commonData = commonData.byReplacing(subnetsInfo: subnetsInfo)

        stateMachine?.transit(to: self)
    }

    func process(networkInfo: SubtensorNetworkInfo?) {
        commonData = commonData.byReplacing(networkInfo: networkInfo)

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

    func process(positionsSyncFailed: Bool) {
        commonData = commonData.byReplacing(positionsSyncFailed: positionsSyncFailed)

        stateMachine?.transit(to: self)
    }
}

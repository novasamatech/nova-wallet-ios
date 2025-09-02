import Foundation

extension ParachainStaking {
    class BaseState: ParaStkStateProtocol {
        weak var stateMachine: ParaStkStateMachineProtocol?

        private(set) var commonData: ParachainStaking.CommonData

        init(
            stateMachine: ParaStkStateMachineProtocol?,
            commonData: ParachainStaking.CommonData
        ) {
            self.stateMachine = stateMachine
            self.commonData = commonData
        }

        func accept(visitor _: ParaStkStateVisitorProtocol) {}

        func process(chainAsset: ChainAsset?) {
            if chainAsset != commonData.chainAsset {
                let commonData = ParachainStaking.CommonData.empty
                    .byReplacing(chainAsset: chainAsset)

                let nextState = ParachainStaking.InitState(
                    stateMachine: stateMachine,
                    commonData: commonData
                )

                stateMachine?.transit(to: nextState)
            }
        }

        func process(account: MetaChainAccountResponse?) {
            let commonData = commonData
                .byReplacing(account: account)
                .byReplacing(balance: nil)
                .byReplacing(yieldBoostState: nil)

            let nextState = ParachainStaking.InitState(
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

        func process(networkInfo: ParachainStaking.NetworkInfo?) {
            commonData = commonData.byReplacing(networkInfo: networkInfo)

            stateMachine?.transit(to: self)
        }

        func process(stakingDuration: ParachainStakingDuration?) {
            commonData = commonData.byReplacing(stakingDuration: stakingDuration)

            stateMachine?.transit(to: self)
        }

        func process(collatorsInfo: SelectedRoundCollators?) {
            commonData = commonData.byReplacing(collatorsInfo: collatorsInfo)

            stateMachine?.transit(to: self)
        }

        func process(calculatorEngine: CollatorStakingRewardCalculatorEngineProtocol?) {
            commonData = commonData.byReplacing(calculatorEngine: calculatorEngine)

            stateMachine?.transit(to: self)
        }

        func process(blockNumber: BlockNumber?) {
            commonData = commonData.byReplacing(blockNumber: blockNumber)

            stateMachine?.transit(to: self)
        }

        func process(roundInfo: ParachainStaking.RoundInfo?) {
            commonData = commonData.byReplacing(roundInfo: roundInfo)

            stateMachine?.transit(to: self)
        }

        func process(totalReward: TotalRewardItem?) {
            commonData = commonData.byReplacing(totalReward: totalReward)

            stateMachine?.transit(to: self)
        }

        func process(yieldBoostState: ParaStkYieldBoostState?) {
            commonData = commonData.byReplacing(yieldBoostState: yieldBoostState)

            stateMachine?.transit(to: self)
        }

        func process(delegatorState _: ParachainStaking.Delegator?) {}

        func process(delegations _: [ParachainStkCollatorSelectionInfo]?) {}

        func process(scheduledRequests _: [ParachainStaking.DelegatorScheduledRequest]?) {}

        func process(totalRewardFilter: StakingRewardFiltersPeriod?) {
            commonData = commonData.byReplacing(totalRewardFilter: totalRewardFilter)

            stateMachine?.transit(to: self)
        }
    }
}

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

        }

        func process(account: MetaChainAccountResponse?) {
            
        }

        func process(balance: AssetBalance?) {

        }

        func process(price: PriceData?) {
            
        }

        func process(networkInfo: ParachainStaking.NetworkInfo?) {

        }

        func process(collatorsInfo: SelectedRoundCollators?) {

        }

        func process(calculatorEngine: ParaStakingRewardCalculatorEngineProtocol?) {

        }

        func process(delegatorState: ParachainStaking.Delegator?) {

        }

        func process(scheduledRequests: [ParachainStaking.ScheduledRequest]?) {
            
        }
    }
}

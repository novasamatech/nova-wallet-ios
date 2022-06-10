import Foundation

final class NoStashState: BaseStakingState {
    init(
        stateMachine: StakingStateMachineProtocol,
        commonData: StakingStateCommonData
    ) {
        super.init(stateMachine: stateMachine, commonData: commonData)
    }

    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(stashItem: StashItem?) {
        if let stashItem = stashItem {
            guard let stateMachine = stateMachine else {
                return
            }

            let newState = StashState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: nil,
                totalReward: nil
            )

            stateMachine.transit(to: newState)
        } else {
            stateMachine?.transit(to: self)
        }
    }
}

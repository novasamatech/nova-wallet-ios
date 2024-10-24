import Foundation

final class InitialStakingState: BaseStakingState {
    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(stashItem: StashItem?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let stashItem = stashItem {
            newState = StashState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: nil,
                totalReward: nil,
                bagListNode: nil
            )
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }
}

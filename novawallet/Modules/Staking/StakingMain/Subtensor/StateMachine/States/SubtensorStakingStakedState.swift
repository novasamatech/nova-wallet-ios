import Foundation

final class SubtensorStakingStakedState: SubtensorStakingBaseState {
    private(set) var stakingState: Multistaking.SubtensorStakingState

    init(
        stateMachine: SubtensorStakingStateMachineProtocol?,
        commonData: SubtensorStakingCommonData,
        stakingState: Multistaking.SubtensorStakingState
    ) {
        self.stakingState = stakingState

        super.init(stateMachine: stateMachine, commonData: commonData)
    }

    override func accept(visitor: SubtensorStakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(positionsState: Multistaking.SubtensorStakingState?) {
        if let positionsState, positionsState.hasActiveStaking {
            stakingState = positionsState

            stateMachine?.transit(to: self)
        } else {
            super.process(positionsState: positionsState)
        }
    }
}

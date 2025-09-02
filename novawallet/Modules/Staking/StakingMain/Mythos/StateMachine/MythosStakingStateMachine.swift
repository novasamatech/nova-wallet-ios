import Foundation

final class MythosStakingStateMachine: MythosStakingStateMachineProtocol {
    private(set) var state: MythosStakingStateProtocol

    weak var delegate: MythosStakingStateMachineDelegate?

    init() {
        let state = MythosStakingTransitionState(stateMachine: nil, commonData: .empty)

        self.state = state

        state.stateMachine = self
    }

    func transit(to state: MythosStakingStateProtocol) {
        self.state = state

        delegate?.stateMachineDidChangeState(self)
    }
}

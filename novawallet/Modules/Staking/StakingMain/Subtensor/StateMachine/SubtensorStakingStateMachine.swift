import Foundation

final class SubtensorStakingStateMachine: SubtensorStakingStateMachineProtocol {
    private(set) var state: SubtensorStakingStateProtocol

    weak var delegate: SubtensorStakingStateMachineDelegate?

    init() {
        let state = SubtensorStakingInitState(stateMachine: nil, commonData: .empty)

        self.state = state

        state.stateMachine = self
    }

    func transit(to state: SubtensorStakingStateProtocol) {
        self.state = state

        delegate?.stateMachineDidChangeState(self)
    }
}

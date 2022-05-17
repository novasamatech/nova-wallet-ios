import Foundation

extension ParachainStaking {
    final class StateMachine: ParaStkStateMachineProtocol {
        private(set) var state: ParaStkStateProtocol

        weak var delegate: ParaStkStateMachineDelegate?

        init() {
            let state = ParachainStaking.InitState(stateMachine: nil, commonData: .empty)

            self.state = state

            state.stateMachine = self
        }

        func transit(to state: ParaStkStateProtocol) {
            self.state = state

            delegate?.stateMachineDidChangeState(self)
        }
    }
}

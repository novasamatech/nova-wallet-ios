import Foundation

class WalletConnectBaseState {
    weak var stateMachine: WalletConnectStateMachineProtocol?

    init(stateMachine: WalletConnectStateMachineProtocol) {
        self.stateMachine = stateMachine
    }

    func emitUnexpected(message: Any, nextState: WalletConnectStateProtocol) {
        stateMachine?.emit(
            error: .unexpectedMessage(message, nextState),
            nextState: nextState
        )
    }
}

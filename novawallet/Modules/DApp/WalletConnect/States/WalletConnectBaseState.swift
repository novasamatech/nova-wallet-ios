import Foundation

class WalletConnectBaseState {
    weak var stateMachine: WalletConnectStateMachineProtocol?
    let logger: LoggerProtocol

    init(stateMachine: WalletConnectStateMachineProtocol, logger: LoggerProtocol) {
        self.stateMachine = stateMachine
        self.logger = logger
    }

    func emitUnexpected(message: Any, nextState: WalletConnectStateProtocol) {
        stateMachine?.emit(
            error: .unexpectedMessage(message, nextState),
            nextState: nextState
        )
    }
}

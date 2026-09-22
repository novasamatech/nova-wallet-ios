import Foundation

class WalletConnectBaseState {
    weak var stateMachine: WalletConnectStateMachineProtocol?
    let logger: LoggerProtocol
    let signingAnalytics: WalletConnectSigningAnalytics

    init(
        stateMachine: WalletConnectStateMachineProtocol,
        logger: LoggerProtocol,
        signingAnalytics: WalletConnectSigningAnalytics
    ) {
        self.stateMachine = stateMachine
        self.logger = logger
        self.signingAnalytics = signingAnalytics
    }

    func emitUnexpected(message: Any, nextState: WalletConnectStateProtocol) {
        stateMachine?.emit(
            error: .unexpectedMessage(message, nextState),
            nextState: nextState
        )
    }
}

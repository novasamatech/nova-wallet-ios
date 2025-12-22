import Foundation
import WalletConnectSign
import SubstrateSdk

final class WalletConnectStateSigning: WalletConnectBaseState {
    let request: Request

    init(request: Request, stateMachine: WalletConnectStateMachineProtocol, logger: LoggerProtocol) {
        self.request = request

        super.init(stateMachine: stateMachine, logger: logger)
    }
}

extension WalletConnectStateSigning: WalletConnectStateProtocol {
    func canHandleMessage() -> Bool {
        false
    }

    func handle(message: WalletConnectTransportMessage, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: message, nextState: self)
    }

    func handleOperation(response: DAppOperationResponse, dataSource _: DAppStateDataSource) {
        guard let stateMachine = stateMachine else {
            return
        }

        let nextState = WalletConnectStateReady(stateMachine: stateMachine, logger: logger)

        if
            let signature = response.signature,
            let method = WalletConnectMethod(rawValue: request.method) {
            let result = WalletConnectSignModelFactory.createSigningResponse(
                for: method,
                signature: signature,
                modifiedTransaction: response.modifiedTransaction
            )

            stateMachine.emit(
                signDecision: .approve(request: request, signature: result),
                nextState: nextState,
                error: nil
            )
        } else {
            stateMachine.emit(signDecision: .reject(request: request), nextState: nextState, error: nil)
        }
    }

    func handleAuth(response: DAppAuthResponse, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: response, nextState: self)
    }

    func proceed(with _: DAppStateDataSource) {}
}

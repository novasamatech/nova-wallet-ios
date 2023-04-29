import Foundation
import WalletConnectSwiftV2

final class WalletConnectStateSigning: WalletConnectBaseState {
    let request: Request

    init(request: Request, stateMachine: WalletConnectStateMachineProtocol) {
        self.request = request

        super.init(stateMachine: stateMachine)
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

        let nextState = WalletConnectStateReady(stateMachine: stateMachine)

        if let signature = response.signature {
            let result = AnyCodable(any: signature.toHex(includePrefix: true))
            stateMachine.emit(
                signDecision: .approve(request: request, signature: result),
                nextState: nextState
            )
        } else {
            stateMachine.emit(signDecision: .reject(request: request), nextState: nextState)
        }
    }

    func handleAuth(response: DAppAuthResponse, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: response, nextState: self)
    }

    func proceed(with _: DAppStateDataSource) {}
}

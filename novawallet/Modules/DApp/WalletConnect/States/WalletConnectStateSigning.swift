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

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppStateDataSource) {}

    func handleAuth(response: DAppAuthResponse, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: response, nextState: self)
    }

    func proceed(with _: DAppStateDataSource) {}
}

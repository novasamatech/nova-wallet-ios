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

    func handle(message: WalletConnectTransportMessage, dataSource: DAppStateDataSource) {
        emitUnexpected(message: message, nextState: self)
    }

    func handleOperation(response: DAppOperationResponse, dataSource: DAppStateDataSource) {

    }

    func handleAuth(response: DAppAuthResponse, dataSource: DAppStateDataSource) {
        emitUnexpected(message: response, nextState: self)
    }

    func proceed(with dataSource: DAppStateDataSource) {}
}

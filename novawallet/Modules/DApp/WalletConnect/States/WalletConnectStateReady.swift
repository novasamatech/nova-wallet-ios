import Foundation

final class WalletConnectStateReady: WalletConnectBaseState {}

extension WalletConnectStateReady: WalletConnectStateProtocol {
    func canHandleMessage() -> Bool {
        true
    }

    func handle(message: WalletConnectTransportMessage, dataSource _: DAppStateDataSource) {
        guard let stateMachine = stateMachine else {
            return
        }

        let nextState = WalletConnectStateNewMessage(
            message: message,
            stateMachine: stateMachine
        )

        stateMachine.emit(nextState: nextState)
    }

    func handleOperation(response: DAppOperationResponse, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: response, nextState: self)
    }

    func handleAuth(response: DAppAuthResponse, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: response, nextState: self)
    }

    func proceed(with _: DAppStateDataSource) {}
}

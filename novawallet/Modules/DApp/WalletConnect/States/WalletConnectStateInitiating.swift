import Foundation

final class WalletConnectStateInitiating: WalletConnectBaseState {}

extension WalletConnectStateInitiating: WalletConnectStateProtocol {
    func canHandleMessage() -> Bool {
        false
    }

    func handle(message: WalletConnectTransportMessage, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: message, nextState: self)
    }

    func handleOperation(response: DAppOperationResponse, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: response, nextState: self)
    }

    func handleAuth(response: DAppAuthResponse, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: response, nextState: self)
    }

    func proceed(with dataSource: DAppStateDataSource) {
        guard let stateMachine = stateMachine else {
            return
        }

        let chainIds = dataSource.chainsStore.availableChainIds()

        if !chainIds.isEmpty {
            stateMachine.emit(nextState: WalletConnectStateReady(stateMachine: stateMachine))
        }
    }
}

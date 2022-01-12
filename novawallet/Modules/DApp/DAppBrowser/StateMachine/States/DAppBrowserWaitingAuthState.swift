import Foundation

final class DAppBrowserWaitingAuthState: DAppBrowserBaseState {}

extension DAppBrowserWaitingAuthState: DAppBrowserStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {
        stateMachine?.popMessage()
    }

    func canHandleMessage() -> Bool { true }

    func handle(message: PolkadotExtensionMessage, dataSource: DAppBrowserStateDataSource) {
        switch message.messageType {
        case .authorize:
            let request = DAppAuthRequest(
                identifier: message.identifier,
                wallet: dataSource.wallet,
                dApp: message.url ?? ""
            )

            let nextState = DAppBrowserAuthorizingState(stateMachine: stateMachine)

            stateMachine?.emit(authRequest: request, nextState: nextState)
        default:
            let error = "auth message expected but \(message.messageType.rawValue) received"
            stateMachine?.emit(error: DAppBrowserStateError.unexpected(reason: error), nextState: self)
        }
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "signing response while waiting auth"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "auth response while waiting request"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }
}

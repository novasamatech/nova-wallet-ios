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
            break
        }
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {}

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {}
}

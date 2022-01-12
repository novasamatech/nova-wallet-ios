import Foundation

final class DAppBrowserAuthorizingState: DAppBrowserBaseState {}

extension DAppBrowserAuthorizingState: DAppBrowserStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {}

    func canHandleMessage() -> Bool { false }

    func handle(message _: PolkadotExtensionMessage, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(reason: "can't handle message while authorizing")

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "signing response while waiting auth response"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleAuth(response: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {
        do {
            if response.approved {
                let nextState = DAppBrowserAuthorizedState(stateMachine: stateMachine)
                try provideResponse(for: .authorize, result: response.approved, nextState: nextState)
            } else {
                let nextState = DAppBrowserDeniedState(stateMachine: stateMachine)
                provideError(
                    for: .authorize,
                    errorMessage: PolkadotExtensionError.rejected.rawValue,
                    nextState: nextState
                )
            }

        } catch {
            stateMachine?.emit(error: error, nextState: self)
        }
    }
}

import Foundation

final class DAppMetamaskDeniedState: DAppMetamaskBaseState {}

extension DAppMetamaskDeniedState: DAppMetamaskStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {}

    func canHandleMessage() -> Bool { false }

    func handle(message _: MetamaskMessage, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(reason: "can't handle message when denied")

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "signing response when denied"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "auth response when denied"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }
}

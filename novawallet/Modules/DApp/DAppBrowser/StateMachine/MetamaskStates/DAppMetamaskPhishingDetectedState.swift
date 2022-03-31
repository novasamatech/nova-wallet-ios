import Foundation

final class DAppMetamaskPhishingDetectedState: DAppMetamaskBaseState {}

extension DAppMetamaskPhishingDetectedState: DAppMetamaskStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {}

    func canHandleMessage() -> Bool { false }

    func fetchSelectedAddress(from _: DAppBrowserStateDataSource) -> AccountAddress? {
        nil
    }

    func handle(message: MetamaskMessage, host: String, dataSource _: DAppBrowserStateDataSource) {
        let message = "can't handle message from \(host) when phishing detected"
        let error = DAppBrowserStateError.unexpected(reason: message)

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "signing response when phishing detected"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "auth response when phishing detected"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }
}

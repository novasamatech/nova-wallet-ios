import Foundation
import RobinHood

final class DAppMetamaskWaitingAuthState: DAppMetamaskBaseState {
    private func completeByRequestingAuth(
        message: MetamaskMessage,
        dataSource: DAppBrowserStateDataSource
    ) {
        let request = DAppAuthRequest(
            transportName: DAppTransports.metamask,
            identifier: "\(message.identifier)",
            wallet: dataSource.wallet,
            origin: dataSource.dApp?.name ?? "",
            dApp: dataSource.dApp?.name ?? "",
            dAppIcon: dataSource.dApp?.icon
        )

        let nextState = DAppMetamaskAuthorizingState(
            stateMachine: stateMachine,
            requestId: message.identifier
        )

        stateMachine?.emit(authRequest: request, nextState: nextState)
    }
}

extension DAppMetamaskWaitingAuthState: DAppMetamaskStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {
        stateMachine?.popMessage()
    }

    func canHandleMessage() -> Bool { true }

    func handle(message: MetamaskMessage, dataSource: DAppBrowserStateDataSource) {
        switch message.name {
        case .requestAccounts:
            completeByRequestingAuth(message: message, dataSource: dataSource)
        default:
            let error = "auth message expected but \(message.name) received"
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

import Foundation
import RobinHood

final class DAppMetamaskWaitingAuthState: DAppMetamaskBaseState {
    private var isHandlingAuthMessage: Bool = false

    private func handle(
        authMessage: MetamaskMessage,
        host: String,
        dataSource: DAppBrowserStateDataSource
    ) {
        let settingsOperation = dataSource.dAppSettingsRepository.fetchOperation(
            by: host,
            options: RepositoryFetchOptions()
        )

        settingsOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                let settings = try? settingsOperation.extractNoCancellableResultData()

                if let allowed = settings?.allowed, allowed {
                    self?.completeByAllowingAccess(for: authMessage, dataSource: dataSource)
                } else {
                    self?.completeByRequestingAuth(
                        message: authMessage,
                        host: host,
                        dataSource: dataSource
                    )
                }
            }
        }

        dataSource.operationQueue.addOperation(settingsOperation)
    }

    private func completeByAllowingAccess(
        for message: MetamaskMessage,
        dataSource: DAppBrowserStateDataSource
    ) {
        let addresses = dataSource.fetchEthereumAddresses()

        let nextState = DAppMetamaskAuthorizedState(stateMachine: stateMachine)

        provideResponse(for: message.identifier, results: addresses, nextState: nextState)
    }

    private func completeByRequestingAuth(
        message: MetamaskMessage,
        host: String,
        dataSource: DAppBrowserStateDataSource
    ) {
        let request = DAppAuthRequest(
            transportName: DAppTransports.metamask,
            identifier: "\(message.identifier)",
            wallet: dataSource.wallet,
            origin: host,
            dApp: host,
            dAppIcon: nil
        )

        let nextState = DAppMetamaskAuthorizingState(
            stateMachine: stateMachine,
            requestId: message.identifier,
            host: host
        )

        stateMachine?.emit(authRequest: request, nextState: nextState)
    }
}

extension DAppMetamaskWaitingAuthState: DAppMetamaskStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {
        stateMachine?.popMessage()
    }

    func canHandleMessage() -> Bool { !isHandlingAuthMessage }

    func handle(message: MetamaskMessage, host: String, dataSource: DAppBrowserStateDataSource) {
        switch message.name {
        case .requestAccounts:
            isHandlingAuthMessage = true
            handle(authMessage: message, host: host, dataSource: dataSource)
        default:
            let error = "auth message expected but \(message.name) received from \(host)"
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

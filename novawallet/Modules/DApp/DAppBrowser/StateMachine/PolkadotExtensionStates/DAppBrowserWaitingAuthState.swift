import Foundation
import RobinHood

final class DAppBrowserWaitingAuthState: DAppBrowserBaseState {
    private var isHandlingAuthMessage: Bool = false

    private func handle(authMessage: PolkadotExtensionMessage, dataSource: DAppBrowserStateDataSource) {
        guard
            let urlString = authMessage.url,
            let host = URL(string: urlString)?.host else {
            completeByRequestingAuth(message: authMessage, dAppIdentifier: nil, dataSource: dataSource)
            return
        }

        let settingsOperation = dataSource.dAppSettingsRepository.fetchOperation(
            by: host,
            options: RepositoryFetchOptions()
        )

        settingsOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                let settings = try? settingsOperation.extractNoCancellableResultData()

                if settings != nil {
                    self?.completeByAllowingAccess(for: authMessage, dataSource: dataSource)
                } else {
                    self?.completeByRequestingAuth(
                        message: authMessage,
                        dAppIdentifier: host,
                        dataSource: dataSource
                    )
                }
            }
        }

        dataSource.operationQueue.addOperation(settingsOperation)
    }

    private func completeByRequestingAuth(
        message: PolkadotExtensionMessage,
        dAppIdentifier: String?,
        dataSource: DAppBrowserStateDataSource
    ) {
        let request = DAppAuthRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: message.identifier,
            wallet: dataSource.wallet,
            origin: message.request?.origin?.stringValue,
            dApp: message.url ?? "",
            dAppIcon: dataSource.dApp?.icon
        )

        let nextState = DAppBrowserAuthorizingState(
            stateMachine: stateMachine,
            dAppIdentifier: dAppIdentifier
        )

        stateMachine?.emit(authRequest: request, nextState: nextState)
    }

    private func completeByAllowingAccess(
        for _: PolkadotExtensionMessage,
        dataSource _: DAppBrowserStateDataSource
    ) {
        do {
            let nextState = DAppBrowserAuthorizedState(stateMachine: stateMachine)
            try provideResponse(for: .authorize, result: true, nextState: nextState)
        } catch {
            stateMachine?.emit(error: error, nextState: self)
        }
    }
}

extension DAppBrowserWaitingAuthState: DAppBrowserStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {
        stateMachine?.popMessage()
    }

    func canHandleMessage() -> Bool { !isHandlingAuthMessage }

    func handle(message: PolkadotExtensionMessage, dataSource: DAppBrowserStateDataSource) {
        switch message.messageType {
        case .authorize:
            isHandlingAuthMessage = true

            handle(authMessage: message, dataSource: dataSource)
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

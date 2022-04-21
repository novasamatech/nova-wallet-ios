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

                if settings != nil {
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
        approveAccountAccess(for: message.identifier, dataSource: dataSource)
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
            chain: chain,
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

    func fetchSelectedAddress(from _: DAppBrowserStateDataSource) -> AccountAddress? {
        nil
    }

    func handle(message: MetamaskMessage, host: String, dataSource: DAppBrowserStateDataSource) {
        switch message.name {
        case .requestAccounts:
            isHandlingAuthMessage = true
            handle(authMessage: message, host: host, dataSource: dataSource)
        case .switchEthereumChain:
            switchChain(
                from: message,
                dataSource: dataSource,
                nextStateSuccessClosure: { newChain in
                    DAppMetamaskWaitingAuthState(stateMachine: stateMachine, chain: newChain)
                },
                nextStateFailureClosure: { _ in
                    DAppMetamaskWaitingAuthState(stateMachine: stateMachine, chain: chain)
                }
            )
        case .addEthereumChain:
            addChain(
                from: message,
                dataSource: dataSource,
                nextStateSuccessClosure: { newChain in
                    DAppMetamaskWaitingAuthState(stateMachine: stateMachine, chain: newChain)
                }, nextStateFailureClosure: { _ in
                    DAppMetamaskWaitingAuthState(stateMachine: stateMachine, chain: chain)
                }
            )
        default:
            let errorMessage = "auth message expected but \(message.name) received from \(host)"
            stateMachine?.emit(error: DAppBrowserStateError.unexpected(reason: errorMessage), nextState: self)
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

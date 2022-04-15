import Foundation
import RobinHood

final class DAppMetamaskAuthorizingState: DAppMetamaskBaseState {
    let requestId: MetamaskMessage.Id
    let host: String

    init(
        stateMachine: DAppMetamaskStateMachineProtocol?,
        chain: MetamaskChain,
        requestId: MetamaskMessage.Id,
        host: String
    ) {
        self.requestId = requestId
        self.host = host

        super.init(stateMachine: stateMachine, chain: chain)
    }

    func saveAuthAndComplete(
        _ approved: Bool,
        host: String,
        dataSource: DAppBrowserStateDataSource
    ) {
        guard approved else {
            complete(false, dataSource: dataSource)
            return
        }

        let saveOperation = dataSource.dAppSettingsRepository.saveOperation({
            let newSettings = DAppSettings(identifier: host, metaId: dataSource.wallet.metaId)

            return [newSettings]
        }, { [] })

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.complete(approved, dataSource: dataSource)
            }
        }

        dataSource.operationQueue.addOperations([saveOperation], waitUntilFinished: false)
    }

    func complete(_ approved: Bool, dataSource: DAppBrowserStateDataSource) {
        if approved {
            approveAccountAccess(for: requestId, dataSource: dataSource)
        } else {
            let nextState = DAppMetamaskDeniedState(stateMachine: stateMachine, chain: chain)

            let error = MetamaskError.rejected
            provideError(for: requestId, error: error, nextState: nextState)
        }
    }
}

extension DAppMetamaskAuthorizingState: DAppMetamaskStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {}

    func canHandleMessage() -> Bool { false }

    func fetchSelectedAddress(from _: DAppBrowserStateDataSource) -> AccountAddress? { nil }

    func handle(message: MetamaskMessage, host: String, dataSource _: DAppBrowserStateDataSource) {
        let message = "can't handle message from \(host) while authorizing"
        let error = DAppBrowserStateError.unexpected(reason: message)

        stateMachine?.emit(error: error, nextState: self)
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "signing response while waiting auth response"
        )

        stateMachine?.emit(error: error, nextState: self)
    }

    func handleAuth(response: DAppAuthResponse, dataSource: DAppBrowserStateDataSource) {
        saveAuthAndComplete(response.approved, host: host, dataSource: dataSource)
    }
}

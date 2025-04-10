import Foundation
import Operation_iOS

final class DAppBrowserAuthorizingState: DAppBrowserBaseState {
    let dAppId: String?
    let requestId: String

    init(
        stateMachine: DAppBrowserStateMachineProtocol?,
        dAppId: String?,
        requestId: String
    ) {
        self.dAppId = dAppId
        self.requestId = requestId

        super.init(stateMachine: stateMachine)
    }

    func saveAuthAndComplete(
        _ approved: Bool,
        dappId: String,
        dataSource: DAppBrowserStateDataSource
    ) {
        guard approved else {
            complete(false)
            return
        }

        let saveOperation = dataSource.dAppSettingsRepository.saveOperation({
            let newSettings = DAppSettings(
                identifier: dappId,
                metaId: dataSource.wallet.metaId,
                source: nil
            )

            return [newSettings]
        }, { [] })

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.complete(true)
            }
        }

        dataSource.operationQueue.addOperations([saveOperation], waitUntilFinished: false)
    }

    func complete(_ approved: Bool) {
        do {
            if approved {
                let nextState = DAppBrowserAuthorizedState(stateMachine: stateMachine)
                try provideResponse(for: requestId, result: true, nextState: nextState)
            } else {
                let nextState = DAppBrowserWaitingAuthState(stateMachine: stateMachine)
                provideError(
                    for: requestId,
                    errorMessage: PolkadotExtensionError.rejected.rawValue,
                    nextState: nextState
                )
            }

        } catch {
            stateMachine?.emit(error: error, nextState: self)
        }
    }
}

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

    func handleAuth(response: DAppAuthResponse, dataSource: DAppBrowserStateDataSource) {
        if let dAppId {
            saveAuthAndComplete(response.approved, dappId: dAppId, dataSource: dataSource)
        } else {
            complete(response.approved)
        }
    }
}

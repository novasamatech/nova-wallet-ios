import Foundation
import RobinHood

final class DAppBrowserAuthorizingState: DAppBrowserBaseState {
    let dAppIdentifier: String?

    init(stateMachine: DAppBrowserStateMachineProtocol?, dAppIdentifier: String?) {
        self.dAppIdentifier = dAppIdentifier

        super.init(stateMachine: stateMachine)
    }

    func saveAuthAndComplete(_ approved: Bool, identifier: String, dataSource: DAppBrowserStateDataSource) {
        guard approved else {
            complete(false)
            return
        }

        let saveOperation = dataSource.dAppSettingsRepository.saveOperation({
            let newSettings = DAppSettings(identifier: identifier, metaId: dataSource.wallet.metaId)

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
                try provideResponse(for: .authorize, result: true, nextState: nextState)
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
        if let dAppIdentifier = dAppIdentifier {
            saveAuthAndComplete(response.approved, identifier: dAppIdentifier, dataSource: dataSource)
        } else {
            complete(response.approved)
        }
    }
}

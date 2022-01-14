import Foundation
import RobinHood

final class DAppBrowserAuthorizingState: DAppBrowserBaseState {
    let dAppIdentifier: String?

    init(stateMachine: DAppBrowserStateMachineProtocol?, dAppIdentifier: String?) {
        self.dAppIdentifier = dAppIdentifier

        super.init(stateMachine: stateMachine)
    }

    func saveAuthAndComplete(_ approved: Bool, identifier: String, dataSource: DAppBrowserStateDataSource) {
        let fetchOperations = dataSource.dAppSettingsRepository.fetchOperation(
            by: identifier,
            options: RepositoryFetchOptions()
        )

        let saveOperation = dataSource.dAppSettingsRepository.saveOperation({
            let currentSettings = try fetchOperations.extractNoCancellableResultData()

            let newSettings = DAppSettings(
                identifier: currentSettings?.identifier ?? identifier,
                allowed: approved,
                favorite: currentSettings?.favorite ?? false
            )

            return [newSettings]
        }, { [] })

        saveOperation.addDependency(fetchOperations)

        dataSource.operationQueue.addOperations([fetchOperations, saveOperation], waitUntilFinished: false)
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

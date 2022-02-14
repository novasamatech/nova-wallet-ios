import Foundation

final class DAppMetamaskSigningState: DAppMetamaskBaseState {
    let requestId: MetamaskMessage.Id

    init(stateMachine: DAppMetamaskStateMachineProtocol?, requestId: MetamaskMessage.Id) {
        self.requestId = requestId

        super.init(stateMachine: stateMachine)
    }
}

extension DAppMetamaskSigningState: DAppMetamaskStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {}

    func canHandleMessage() -> Bool { false }

    func handle(message: MetamaskMessage, host: String, dataSource _: DAppBrowserStateDataSource) {
        let message = "can't handle message from \(host) while signing"
        let error = DAppBrowserStateError.unexpected(reason: message)

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleOperation(response: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let nextState = DAppMetamaskAuthorizedState(stateMachine: stateMachine)

        if let signature = response.signature {
            do {
                let signatureHex = signature.toHex(includePrefix: true)
                try provideResponse(for: requestId, result: signatureHex, nextState: nextState)
            } catch {
                stateMachine?.emit(error: error, nextState: nextState)
            }
        } else {
            let error = PolkadotExtensionError.rejected.rawValue
            provideError(for: requestId, errorMessage: error, nextState: nextState)
        }
    }

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "auth response when signing"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }
}

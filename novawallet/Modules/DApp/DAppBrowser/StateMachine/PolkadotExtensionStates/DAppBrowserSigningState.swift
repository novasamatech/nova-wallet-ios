import Foundation

final class DAppBrowserSigningState: DAppBrowserBaseState {
    let signingType: DAppSigningType
    let requestId: String

    init(
        stateMachine: DAppBrowserStateMachineProtocol?,
        signingType: DAppSigningType,
        requestId: String
    ) {
        self.signingType = signingType
        self.requestId = requestId

        super.init(stateMachine: stateMachine)
    }

    private func provideOperationResponse(
        with signature: Data,
        modifiedTransaction: Data?,
        nextState: DAppBrowserStateProtocol
    ) throws {
        let identifier = (0 ... UInt32.max).randomElement() ?? 0
        let result = PolkadotExtensionSignerResult(
            identifier: UInt(identifier),
            signature: signature.toHex(includePrefix: true),
            signedTransaction: modifiedTransaction?.toHex(includePrefix: true)
        )

        try provideResponse(for: requestId, result: result, nextState: nextState)
    }

    private func providerOperationError(
        _ error: PolkadotExtensionError,
        nextState: DAppBrowserStateProtocol
    ) {
        provideError(for: requestId, errorMessage: error.rawValue, nextState: nextState)
    }
}

extension DAppBrowserSigningState: DAppBrowserStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {}

    func canHandleMessage() -> Bool { false }

    func handle(message _: PolkadotExtensionMessage, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(reason: "can't handle message while signing")

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleOperation(response: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let nextState = DAppBrowserAuthorizedState(stateMachine: stateMachine)

        if let signature = response.signature {
            do {
                try provideOperationResponse(
                    with: signature,
                    modifiedTransaction: response.modifiedTransaction,
                    nextState: nextState
                )
            } catch {
                stateMachine?.emit(error: error, nextState: nextState)
            }
        } else {
            providerOperationError(.rejected, nextState: nextState)
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

import Foundation

final class DAppBrowserSigningState: DAppBrowserBaseState {
    let signingType: DAppSigningType

    init(stateMachine: DAppBrowserStateMachineProtocol?, signingType: DAppSigningType) {
        self.signingType = signingType

        super.init(stateMachine: stateMachine)
    }

    private func provideOperationResponse(with signature: Data, nextState: DAppBrowserStateProtocol) throws {
        guard let msgType = signingType.msgType else {
            return
        }

        let identifier = (0 ... UInt32.max).randomElement() ?? 0
        let result = PolkadotExtensionSignerResult(
            identifier: UInt(identifier),
            signature: signature.toHex(includePrefix: true)
        )

        try provideResponse(for: msgType, result: result, nextState: nextState)
    }

    private func providerOperationError(
        _ error: PolkadotExtensionError,
        nextState: DAppBrowserStateProtocol
    ) {
        guard let msgType = signingType.msgType else {
            return
        }

        provideError(for: msgType, errorMessage: error.rawValue, nextState: nextState)
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
                try provideOperationResponse(with: signature, nextState: nextState)
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

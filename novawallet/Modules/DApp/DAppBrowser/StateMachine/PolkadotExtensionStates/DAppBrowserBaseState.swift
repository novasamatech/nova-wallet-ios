import Foundation

class DAppBrowserBaseState {
    weak var stateMachine: DAppBrowserStateMachineProtocol?

    init(stateMachine: DAppBrowserStateMachineProtocol?) {
        self.stateMachine = stateMachine
    }

    func parseMessage(_ message: Any) -> PolkadotExtensionMessage? {
        guard
            let dict = message as? NSDictionary,
            let parsedMessage = try? dict.map(to: PolkadotExtensionMessage.self) else {
            return nil
        }

        return parsedMessage
    }

    func provideResponse<T: Encodable>(
        for requestId: String,
        result: T,
        nextState: DAppBrowserStateProtocol
    ) throws {
        guard
            let data = try? JSONEncoder().encode(result),
            let dataString = String(data: data, encoding: .utf8) else {
            throw DAppBrowserStateError.unexpected(reason: "invalid response result")
        }

        let content = String(
            format: "window.walletExtension.onAppResponse(%@, %@, null)",
            try createRequestIdLiteral(requestId),
            dataString
        )

        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }

    func provideError(
        for requestId: String,
        errorMessage: String,
        nextState: DAppBrowserStateProtocol
    ) {
        guard let response = createErrorResponse(for: requestId, errorMessage: errorMessage) else {
            let error = DAppBrowserStateError.unexpected(reason: "invalid error message")
            stateMachine?.emit(error: error, nextState: nextState)
            return
        }

        stateMachine?.emit(response: response, nextState: nextState)
    }

    /**
     *  Answers a createTransaction request with a failure the RFC defines. The user sees nothing
     *  of it at this point, so the state machine is told the reason to leave a trace in the logs.
     */
    func provideFailure(
        for requestId: String,
        error: DAppCreateTransactionError,
        nextState: DAppBrowserStateProtocol
    ) {
        guard let response = createErrorResponse(for: requestId, errorMessage: error.responseMessage) else {
            let stateError = DAppBrowserStateError.unexpected(reason: "invalid error message")
            stateMachine?.emit(error: stateError, nextState: nextState)
            return
        }

        stateMachine?.emit(failureResponse: response, reason: error.responseMessage, nextState: nextState)
    }

    func provideSubscription<T: Encodable>(
        for requestId: String,
        result: T,
        nextState: DAppBrowserStateProtocol
    ) throws {
        guard
            let data = try? JSONEncoder().encode(result),
            let dataString = String(data: data, encoding: .utf8) else {
            throw DAppBrowserStateError.unexpected(reason: "invalid subscription result")
        }

        let content = String(
            format: "window.walletExtension.onAppSubscription(%@, %@)",
            try createRequestIdLiteral(requestId),
            dataString
        )

        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }
}

// MARK: Private

private extension DAppBrowserBaseState {
    /**
     *  The request id and the error message come from the page: a JSON string is a valid JS literal
     *  whatever it contains, so the value can't leave the argument it is written to.
     */
    func createStringLiteral(_ value: String) -> String? {
        guard let data = try? JSONEncoder().encode(value) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func createErrorResponse(for requestId: String, errorMessage: String) -> DAppScriptResponse? {
        guard
            let requestIdLiteral = createStringLiteral(requestId),
            let messageLiteral = createStringLiteral(errorMessage) else {
            return nil
        }

        let content = String(
            format: "window.walletExtension.onAppResponse(%@, null, new Error(%@))",
            requestIdLiteral,
            messageLiteral
        )

        return DAppScriptResponse(content: content)
    }

    func createRequestIdLiteral(_ requestId: String) throws -> String {
        guard let literal = createStringLiteral(requestId) else {
            throw DAppBrowserStateError.unexpected(reason: "invalid request id")
        }

        return literal
    }
}

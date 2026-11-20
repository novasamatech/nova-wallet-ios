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
        guard
            let requestIdLiteral = createStringLiteral(requestId),
            let messageLiteral = createStringLiteral(errorMessage) else {
            let error = DAppBrowserStateError.unexpected(reason: "invalid error message")
            stateMachine?.emit(error: error, nextState: nextState)
            return
        }

        let content = String(
            format: "window.walletExtension.onAppResponse(%@, null, new Error(%@))",
            requestIdLiteral,
            messageLiteral
        )

        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
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

    func createRequestIdLiteral(_ requestId: String) throws -> String {
        guard let literal = createStringLiteral(requestId) else {
            throw DAppBrowserStateError.unexpected(reason: "invalid request id")
        }

        return literal
    }
}

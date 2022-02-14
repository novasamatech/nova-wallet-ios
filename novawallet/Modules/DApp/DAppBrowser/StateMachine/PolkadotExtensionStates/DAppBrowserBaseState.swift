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
        for messageType: PolkadotExtensionMessage.MessageType,
        result: T,
        nextState: DAppBrowserStateProtocol
    ) throws {
        guard
            let data = try? JSONEncoder().encode(result),
            let dataString = String(data: data, encoding: .utf8) else {
            throw DAppBrowserStateError.unexpected(reason: "invalid response result")
        }

        let content = String(
            format: "window.walletExtension.onAppResponse(\"%@\", %@, null)", messageType.rawValue, dataString
        )

        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }

    func provideError(
        for messageType: PolkadotExtensionMessage.MessageType,
        errorMessage: String,
        nextState: DAppBrowserStateProtocol
    ) {
        let content = String(
            format: "window.walletExtension.onAppResponse(\"%@\", null, new Error(\"%@\"))",
            messageType.rawValue, errorMessage
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
            format: "window.walletExtension.onAppSubscription(\"%@\", %@)", requestId, dataString
        )

        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }
}

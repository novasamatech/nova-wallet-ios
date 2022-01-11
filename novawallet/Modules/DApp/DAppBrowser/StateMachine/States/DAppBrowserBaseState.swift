import Foundation

class DAppBrowserBaseState {
    weak var stateMachine: DAppBrowserStateMachineProtocol?

    init(stateMachine: DAppBrowserStateMachineProtocol?) {
        self.stateMachine = stateMachine
    }

    func provideResponse<T: Encodable>(
        for messageType: PolkadotExtensionMessage.MessageType,
        result: T,
        nextState: DAppBrowserStateProtocol
    ) throws {
        let data = try JSONEncoder().encode(result)

        guard let dataString = String(data: data, encoding: .utf8) else {
            return
        }

        let content = String(
            format: "window.walletExtension.onAppResponse(\"%@\", %@, null)", messageType.rawValue, dataString
        )

        let response = PolkadotExtensionResponse(content: content)

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

        let response = PolkadotExtensionResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }

    func provideSubscription<T: Encodable>(
        for requestId: String,
        result: T,
        nextState: DAppBrowserStateProtocol
    ) throws {
        let data = try JSONEncoder().encode(result)

        guard let dataString = String(data: data, encoding: .utf8) else {
            return
        }

        let content = String(
            format: "window.walletExtension.onAppSubscription(\"%@\", %@)", requestId, dataString
        )

        let response = PolkadotExtensionResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }
}

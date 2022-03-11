import Foundation

protocol DAppBrowserStateMachineProtocol: AnyObject {
    func emit(nextState: DAppBrowserStateProtocol)
    func emit(response: DAppScriptResponse, nextState: DAppBrowserStateProtocol)
    func emit(authRequest: DAppAuthRequest, nextState: DAppBrowserStateProtocol)
    func emit(
        signingRequest: DAppOperationRequest,
        type: DAppSigningType,
        nextState: DAppBrowserStateProtocol
    )
    func emit(error: Error, nextState: DAppBrowserStateProtocol)
    func popMessage()
}

protocol DAppBrowserStateProtocol {
    var stateMachine: DAppBrowserStateMachineProtocol? { get set }

    func setup(with dataSource: DAppBrowserStateDataSource)
    func canHandleMessage() -> Bool
    func handle(message: PolkadotExtensionMessage, dataSource: DAppBrowserStateDataSource)
    func handleOperation(response: DAppOperationResponse, dataSource: DAppBrowserStateDataSource)
    func handleAuth(response: DAppAuthResponse, dataSource: DAppBrowserStateDataSource)
}

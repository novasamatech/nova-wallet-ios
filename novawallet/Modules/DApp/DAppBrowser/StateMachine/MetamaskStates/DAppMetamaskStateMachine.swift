import Foundation

protocol DAppMetamaskStateMachineProtocol: AnyObject {
    func emit(nextState: DAppMetamaskStateProtocol)
    func emit(response: PolkadotExtensionResponse, nextState: DAppMetamaskStateProtocol)
    func emit(authRequest: DAppAuthRequest, nextState: DAppMetamaskStateProtocol)
    func emit(
        signingRequest: DAppOperationRequest,
        type: DAppSigningType,
        nextState: DAppMetamaskStateProtocol
    )
    func emit(
        chain: MetamaskChain,
        postExecutionScript: PolkadotExtensionResponse,
        nextState: DAppMetamaskStateProtocol
    )
    func emit(error: Error, nextState: DAppMetamaskStateProtocol)
    func popMessage()
}

protocol DAppMetamaskStateProtocol {
    var stateMachine: DAppMetamaskStateMachineProtocol? { get set }

    func setup(with dataSource: DAppBrowserStateDataSource)
    func canHandleMessage() -> Bool
    func handle(message: MetamaskMessage, dataSource: DAppBrowserStateDataSource)
    func handleOperation(response: DAppOperationResponse, dataSource: DAppBrowserStateDataSource)
    func handleAuth(response: DAppAuthResponse, dataSource: DAppBrowserStateDataSource)
}

import Foundation
import SubstrateSdk

protocol DAppMetamaskStateMachineProtocol: AnyObject {
    func emit(nextState: DAppMetamaskStateProtocol)
    func emit(response: DAppScriptResponse, nextState: DAppMetamaskStateProtocol)
    func emit(authRequest: DAppAuthRequest, nextState: DAppMetamaskStateProtocol)
    func emit(
        messageId: MetamaskMessage.Id,
        signingOperation: JSON,
        nextState: DAppMetamaskStateProtocol
    )
    func emitReload(with postExecutionScript: DAppScriptResponse, nextState: DAppMetamaskStateProtocol)
    func emit(error: Error, nextState: DAppMetamaskStateProtocol)
    func popMessage()
}

protocol DAppMetamaskStateProtocol {
    var stateMachine: DAppMetamaskStateMachineProtocol? { get set }
    var chain: MetamaskChain { get }

    func fetchSelectedAddress(from dataSource: DAppBrowserStateDataSource) -> AccountAddress?

    func setup(with dataSource: DAppBrowserStateDataSource)
    func canHandleMessage() -> Bool
    func handle(message: MetamaskMessage, host: String, dataSource: DAppBrowserStateDataSource)
    func handleOperation(response: DAppOperationResponse, dataSource: DAppBrowserStateDataSource)
    func handleAuth(response: DAppAuthResponse, dataSource: DAppBrowserStateDataSource)
}

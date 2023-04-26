import Foundation
import WalletConnectSwiftV2

protocol WalletConnectStateMachineProtocol: AnyObject {
    func emit(nextState: WalletConnectStateProtocol)
    func emit(authRequest: DAppAuthRequest, nextState: WalletConnectStateProtocol)
    func emit(
        signingRequest: DAppOperationRequest,
        type: DAppSigningType,
        nextState: WalletConnectStateProtocol
    )
    func emit(error: Error, nextState: WalletConnectStateProtocol)
}

protocol WalletConnectStateProtocol: AnyObject {
    var stateMachine: WalletConnectStateMachineProtocol? { get set }

    func canHandleMessage() -> Bool

    func handle(message: WalletConnectStateMessage, dataSource: DAppBrowserStateDataSource)
    func handleOperation(response: DAppOperationResponse, dataSource: DAppBrowserStateDataSource)
    func handleAuth(response: DAppAuthResponse, dataSource: DAppBrowserStateDataSource)
}

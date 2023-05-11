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
    func emit(proposalDecision: WalletConnectProposalDecision, nextState: WalletConnectStateProtocol)
    func emit(signDecision: WalletConnectSignDecision, nextState: WalletConnectStateProtocol)
    func emit(error: WalletConnectStateError, nextState: WalletConnectStateProtocol)
}

protocol WalletConnectStateProtocol: AnyObject {
    var stateMachine: WalletConnectStateMachineProtocol? { get set }

    func canHandleMessage() -> Bool

    func handle(message: WalletConnectTransportMessage, dataSource: DAppStateDataSource)
    func handleOperation(response: DAppOperationResponse, dataSource: DAppStateDataSource)
    func handleAuth(response: DAppAuthResponse, dataSource: DAppStateDataSource)
    func proceed(with dataSource: DAppStateDataSource)
}

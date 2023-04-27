import Foundation
import WalletConnectSwiftV2

class WalletConnectStateAuthorizing: WalletConnectBaseState {
    let proposal: Session.Proposal
    let resolution: WalletConnectProposalResolution

    init(
        proposal: Session.Proposal,
        resolution: WalletConnectProposalResolution,
        stateMachine: WalletConnectStateMachineProtocol
    ) {
        self.proposal = proposal
        self.resolution = resolution

        super.init(stateMachine: stateMachine)
    }
}

extension WalletConnectStateAuthorizing: WalletConnectStateProtocol {
    func canHandleMessage() -> Bool {
        false
    }

    func handle(message: WalletConnectTransportMessage, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: message, nextState: self)
    }

    func handleOperation(response: DAppOperationResponse, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: response, nextState: self)
    }

    func handleAuth(response: DAppAuthResponse, dataSource _: DAppStateDataSource) {
        guard let stateMachine = stateMachine else {
            return
        }

        let nextState = WalletConnectStateReady(stateMachine: stateMachine)

        guard response.approved else {
            stateMachine.emit(proposalDecision: .reject(proposal: proposal), nextState: nextState)
            return
        }

        let namespaces = WalletConnectModelFactory.createSessionNamespaces(
            from: proposal,
            wallet: response.wallet,
            resolvedChains: resolution.allResolvedChains().resolved
        )

        stateMachine.emit(
            proposalDecision: .approve(proposal: proposal, namespaces: namespaces),
            nextState: nextState
        )
    }

    func proceed(with _: DAppStateDataSource) {}
}

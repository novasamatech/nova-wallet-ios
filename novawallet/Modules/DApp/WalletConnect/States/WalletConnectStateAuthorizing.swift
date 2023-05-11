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

    private func save(
        authResponse: DAppAuthResponse,
        pairingId: String,
        dataSource: DAppStateDataSource,
        completion: @escaping (Error?) -> Void
    ) {
        let saveOperation = dataSource.dAppSettingsRepository.saveOperation({
            if authResponse.approved {
                let settings = DAppSettings(
                    identifier: pairingId,
                    metaId: authResponse.wallet.metaId,
                    source: DAppTransports.walletConnect
                )

                return [settings]
            } else {
                return []
            }
        }, {
            if !authResponse.approved {
                return [pairingId]
            } else {
                return []
            }
        })

        saveOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    try saveOperation.extractNoCancellableResultData()

                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }

        dataSource.operationQueue.addOperation(saveOperation)
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

    func handleAuth(response: DAppAuthResponse, dataSource: DAppStateDataSource) {
        guard let stateMachine = stateMachine else {
            return
        }

        let nextState = WalletConnectStateReady(stateMachine: stateMachine)

        save(
            authResponse: response,
            pairingId: proposal.pairingTopic,
            dataSource: dataSource
        ) { [weak self] optError in
            guard let proposal = self?.proposal, let resolution = self?.resolution else {
                return
            }

            guard optError == nil else {
                // TODO: Also notify error
                stateMachine.emit(proposalDecision: .reject(proposal: proposal), nextState: nextState)
                return
            }

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
    }

    func proceed(with _: DAppStateDataSource) {}
}

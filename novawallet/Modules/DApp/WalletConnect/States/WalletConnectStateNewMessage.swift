import Foundation
import WalletConnectSwiftV2
import SubstrateSdk

final class WalletConnectStateNewMessage: WalletConnectBaseState {
    struct ResolutionResult {
        let resolved: [Blockchain: ChainModel]
        let unresolved: Set<String>

        func adding(chain: ChainModel, blockchain: Blockchain) -> ResolutionResult {
            var newResolved = resolved
            newResolved[blockchain] = chain

            return .init(resolved: newResolved, unresolved: unresolved)
        }

        func adding(unresolvedId: String) -> ResolutionResult {
            let newUnresolved = unresolved.union([unresolvedId])
            return .init(resolved: resolved, unresolved: newUnresolved)
        }
    }

    let message: WalletConnectTransportMessage

    init(
        message: WalletConnectTransportMessage,
        stateMachine: WalletConnectStateMachineProtocol
    ) {
        self.message = message

        super.init(stateMachine: stateMachine)
    }

    private func process(proposal: Session.Proposal, dataSource: DAppStateDataSource) {
        guard let stateMachine = stateMachine else {
            return
        }

        let resolution = WalletConnectModelFactory.createProposalResolution(
            from: proposal,
            chainsStore: dataSource.chainsStore
        )

        let authRequest = DAppAuthRequest(
            transportName: DAppTransports.walletConnect,
            identifier: proposal.pairingTopic,
            wallet: dataSource.walletSettings.value,
            origin: proposal.proposer.url,
            dApp: proposal.proposer.name,
            dAppIcon: proposal.proposer.icons.first.flatMap { URL(string: $0) },
            requiredChains: .init(wcResolution: resolution.requiredNamespaces),
            optionalChains: resolution.optionalNamespaces.map { DAppChainsResolution(wcResolution: $0) }
        )

        let nextState = WalletConnectStateAuthorizing(
            proposal: proposal,
            resolution: resolution,
            stateMachine: stateMachine
        )

        stateMachine.emit(authRequest: authRequest, nextState: nextState)
    }

    private func rejectRequest(request: Request) {
        guard let stateMachine = stateMachine else {
            return
        }

        let desicion = WalletConnectSignDecision.reject(request: request)

        stateMachine.emit(
            signDecision: desicion,
            nextState: WalletConnectStateReady(stateMachine: stateMachine)
        )
    }

    private func fetchWallet(
        for session: Session,
        dataSource: DAppStateDataSource,
        completion: @escaping (MetaAccountModel?) -> Void
    ) {
        let settingsOperation = dataSource.dAppSettingsRepository.fetchOperation(
            by: { session.pairingTopic },
            options: .init()
        )

        let walletOperation = dataSource.walletsRepository.fetchOperation(
            by: {
                if let metaId = try settingsOperation.extractNoCancellableResultData()?.metaId {
                    return metaId
                } else {
                    throw ChainAccountFetchingError.accountNotExists
                }

            },
            options: .init()
        )

        walletOperation.addDependency(settingsOperation)

        walletOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let wallet = try walletOperation.extractNoCancellableResultData()
                    completion(wallet)
                } catch {
                    completion(nil)
                }
            }
        }

        let operations = [settingsOperation, walletOperation]

        dataSource.operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func processSign(
        request: Request,
        session: Session?,
        wallet: MetaAccountModel,
        chainsStore: ChainsStoreProtocol
    ) {
        guard let stateMachine = stateMachine else {
            return
        }

        guard let method = WalletConnectMethod(rawValue: request.method) else {
            rejectRequest(request: request)
            return
        }

        guard
            let chain = WalletConnectModelFactory.resolveChain(
                for: request.chainId,
                chainsStore: chainsStore
            ) else {
            rejectRequest(request: request)
            return
        }

        guard
            let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            rejectRequest(request: request)
            return
        }

        do {
            let operationData = try WalletConnectSignModelFactory.createOperationData(
                for: wallet,
                chain: chain,
                params: request.params,
                method: method
            )

            let signingType = try WalletConnectSignModelFactory.createSigningType(
                for: wallet,
                chain: chain,
                method: method
            )

            let signingRequest = DAppOperationRequest(
                transportName: DAppTransports.walletConnect,
                identifier: request.id.string,
                wallet: wallet,
                accountId: accountId,
                dApp: session?.peer.url ?? "",
                dAppIcon: session?.peer.icons.first.flatMap { URL(string: $0) },
                operationData: operationData
            )

            let nextState = WalletConnectStateSigning(request: request, stateMachine: stateMachine)

            stateMachine.emit(
                signingRequest: signingRequest,
                type: signingType,
                nextState: nextState
            )
        } catch {
            // TODO: Handle error

            rejectRequest(request: request)
        }
    }
}

extension WalletConnectStateNewMessage: WalletConnectStateProtocol {
    func canHandleMessage() -> Bool {
        false
    }

    func handle(message _: WalletConnectTransportMessage, dataSource _: DAppStateDataSource) {}

    func handleOperation(response: DAppOperationResponse, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: response, nextState: self)
    }

    func handleAuth(response: DAppAuthResponse, dataSource _: DAppStateDataSource) {
        emitUnexpected(message: response, nextState: self)
    }

    func proceed(with dataSource: DAppStateDataSource) {
        switch message {
        case let .proposal(proposal):
            process(proposal: proposal, dataSource: dataSource)
        case let .request(request, session):
            guard let session = session else {
                // TODO: No session found error
                return
            }

            fetchWallet(for: session, dataSource: dataSource) { [weak self] optWallet in
                if let wallet = optWallet {
                    self?.processSign(
                        request: request,
                        session: session,
                        wallet: wallet,
                        chainsStore: dataSource.chainsStore
                    )
                } else {
                    // TODO: Handle not authorized request
                    self?.rejectRequest(request: request)
                }
            }
        }
    }
}

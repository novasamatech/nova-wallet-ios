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

        let requiredChains = Set(resolution.requiredNamespaces.resolved.values)
        let optionalChains = resolution.optionalNamespaces.map { Set($0.resolved.values) }
        let unresolvedChains = resolution.requiredNamespaces.unresolved.union(
            resolution.optionalNamespaces?.unresolved ?? []
        )

        let authRequest = DAppAuthRequest(
            transportName: DAppTransports.walletConnect,
            identifier: proposal.pairingTopic,
            wallet: dataSource.walletSettings.value,
            origin: proposal.proposer.url,
            dApp: proposal.proposer.name,
            dAppIcon: proposal.proposer.icons.first.flatMap { URL(string: $0) },
            requiredChains: requiredChains,
            optionalChains: optionalChains,
            unknownChains: !unresolvedChains.isEmpty ? unresolvedChains : nil
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

    private func processSign(request: Request, session: Session?, dataSource: DAppStateDataSource) {
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
                chainsStore: dataSource.chainsStore
            ) else {
            rejectRequest(request: request)
            return
        }

        guard
            let accountId = dataSource.walletSettings.value.fetch(
                for: chain.accountRequest()
            )?.accountId else {
            rejectRequest(request: request)
            return
        }

        do {
            let operationData = try WalletConnectSignModelFactory.createOperationData(
                for: dataSource.walletSettings.value,
                chain: chain,
                params: request.params,
                method: method
            )

            let signingType = try WalletConnectSignModelFactory.createSigningType(
                for: dataSource.walletSettings.value,
                chain: chain,
                method: method
            )

            let signingRequest = DAppOperationRequest(
                transportName: DAppTransports.walletConnect,
                identifier: request.id.string,
                wallet: dataSource.walletSettings.value,
                accountId: accountId,
                dApp: session?.peer.name ?? "",
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
            processSign(request: request, session: session, dataSource: dataSource)
        }
    }
}

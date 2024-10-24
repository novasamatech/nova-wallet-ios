import Foundation
import Operation_iOS
import SubstrateSdk

final class AssetsHydraExchangeProvider: AssetsExchangeBaseProvider {
    let chainRegistry: ChainRegistryProtocol

    private var supportedChains: [ChainModel.Id: ChainModel]?
    let operationQueue: OperationQueue
    let selectedWallet: MetaAccountModel

    init(
        selectedWallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.selectedWallet = selectedWallet
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue

        super.init(
            syncQueue: DispatchQueue(label: "io.novawallet.hydraexchangeprovider.\(UUID().uuidString)"),
            logger: logger
        )
    }

    private func createOmnipoolExchange(
        for chain: ChainModel,
        selectedAccount: ChainAccountResponse,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol
    ) -> AssetsHydraOmnipoolExchange {
        let flowState = HydraOmnipoolFlowState(
            account: selectedAccount,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeService,
            operationQueue: operationQueue
        )

        return AssetsHydraOmnipoolExchange(
            chain: chain,
            tokensFactory: HydraOmnipoolTokensFactory(
                chain: chain,
                runtimeService: runtimeService,
                connection: connection,
                operationQueue: operationQueue
            ),
            quoteFactory: HydraOmnipoolQuoteFactory(flowState: flowState),
            runtimeService: runtimeService,
            logger: logger
        )
    }

    private func createStableswapExchange(
        for chain: ChainModel,
        selectedAccount: ChainAccountResponse,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol
    ) -> AssetsHydraStableswapExchange {
        let flowState = HydraStableswapFlowState(
            account: selectedAccount,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeService,
            operationQueue: operationQueue
        )

        return AssetsHydraStableswapExchange(
            chain: chain,
            swapFactory: .init(
                chain: chain,
                runtimeService: runtimeService,
                connection: connection,
                operationQueue: operationQueue
            ),
            quoteFactory: HydraStableswapQuoteFactory(flowState: flowState),
            runtimeService: runtimeService,
            logger: logger
        )
    }

    private func createXYKExchange(
        for chain: ChainModel,
        selectedAccount: ChainAccountResponse,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol
    ) -> AssetsHydraXYKExchange {
        let flowState = HydraXYKFlowState(
            account: selectedAccount,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeService,
            operationQueue: operationQueue
        )

        return AssetsHydraXYKExchange(
            chain: chain,
            tokensFactory: .init(
                chain: chain,
                runtimeService: runtimeService,
                connection: connection,
                operationQueue: operationQueue
            ),
            quoteFactory: .init(flowState: flowState),
            runtimeProvider: runtimeService,
            logger: logger
        )
    }

    private func updateStateIfNeeded() {
        guard let supportedChains else {
            return
        }

        let exchanges: [AssetsExchangeProtocol] = supportedChains.values.flatMap { chain in
            guard
                let selectedAccount = selectedWallet.fetch(for: chain.accountRequest()),
                let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
                let connection = chainRegistry.getConnection(for: chain.chainId) else {
                logger.warning("Account or connection/runtime unavailable for \(chain.name)")
                return [AssetsExchangeProtocol]()
            }

            let omnipoolExchange = createOmnipoolExchange(
                for: chain,
                selectedAccount: selectedAccount,
                connection: connection,
                runtimeService: runtimeService
            )

            let stableswapExchange = createStableswapExchange(
                for: chain,
                selectedAccount: selectedAccount,
                connection: connection,
                runtimeService: runtimeService
            )

            let xykExchange = createXYKExchange(
                for: chain,
                selectedAccount: selectedAccount,
                connection: connection,
                runtimeService: runtimeService
            )

            return [omnipoolExchange, stableswapExchange, xykExchange]
        }

        updateState(with: exchanges)
    }

    private func handleChains(changes: [DataProviderChange<ChainModel>]) -> Bool {
        let updatedChains = changes.reduce(into: supportedChains ?? [:]) { accum, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                accum[newItem.chainId] = newItem.hasSwapHydra ? newItem : nil
            case let .delete(deletedIdentifier):
                accum[deletedIdentifier] = nil
            }
        }

        guard supportedChains != updatedChains else {
            return false
        }

        supportedChains = updatedChains

        return true
    }

    // MARK: Subsclass

    override func performSetup() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: syncQueue,
            filterStrategy: nil
        ) { [weak self] changes in
            guard let self, handleChains(changes: changes) else {
                return
            }

            updateStateIfNeeded()
        }
    }

    override func performThrottle() {
        chainRegistry.chainsUnsubscribe(self)
    }
}

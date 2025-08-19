import Foundation
import Operation_iOS
import SubstrateSdk

final class AssetsHydraExchangeProvider: AssetsExchangeBaseProvider {
    private var supportedChains: [ChainModel.Id: ChainModel]?
    let selectedWallet: MetaAccountModel
    let substrateStorageFacade: StorageFacadeProtocol
    let userStorageFacade: StorageFacadeProtocol
    let exchangeStateRegistrar: AssetsExchangeStateRegistring

    private var hosts: [ChainModel.Id: HydraExchangeHostProtocol] = [:]

    init(
        selectedWallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        pathCostEstimator: AssetsExchangePathCostEstimating,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        exchangeStateRegistrar: AssetsExchangeStateRegistring,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.selectedWallet = selectedWallet
        self.substrateStorageFacade = substrateStorageFacade
        self.userStorageFacade = userStorageFacade
        self.exchangeStateRegistrar = exchangeStateRegistrar

        super.init(
            chainRegistry: chainRegistry,
            pathCostEstimator: pathCostEstimator,
            operationQueue: operationQueue,
            syncQueue: DispatchQueue(label: "io.novawallet.hydraexchangeprovider.\(UUID().uuidString)"),
            logger: logger
        )
    }

    private func createOmnipoolExchange(
        from host: HydraExchangeHostProtocol,
        registeringStateIn stateProviderRegistrar: AssetsExchangeStateRegistring
    ) -> AssetsHydraOmnipoolExchange {
        let flowState = HydraOmnipoolFlowState(
            account: host.selectedAccount,
            chain: host.chain,
            connection: host.connection,
            runtimeProvider: host.runtimeService,
            notificationsRegistrar: exchangeStateRegistrar,
            operationQueue: host.operationQueue
        )

        stateProviderRegistrar.addStateProvider(flowState)

        return AssetsHydraOmnipoolExchange(
            host: host,
            tokensFactory: HydraOmnipoolTokensFactory(
                chain: host.chain,
                runtimeService: host.runtimeService,
                connection: host.connection,
                operationQueue: host.operationQueue
            ),
            quoteFactory: HydraOmnipoolQuoteFactory(flowState: flowState),
            logger: logger
        )
    }

    private func createStableswapExchange(
        from host: HydraExchangeHostProtocol,
        registeringStateIn stateProviderRegistrar: AssetsExchangeStateRegistring
    ) -> AssetsHydraStableswapExchange {
        let flowState = HydraStableswapFlowState(
            account: host.selectedAccount,
            chain: host.chain,
            connection: host.connection,
            runtimeProvider: host.runtimeService,
            notificationsRegistrar: exchangeStateRegistrar,
            operationQueue: host.operationQueue
        )

        stateProviderRegistrar.addStateProvider(flowState)

        return AssetsHydraStableswapExchange(
            host: host,
            swapFactory: .init(
                chain: host.chain,
                runtimeService: host.runtimeService,
                connection: host.connection,
                operationQueue: host.operationQueue
            ),
            quoteFactory: HydraStableswapQuoteFactory(flowState: flowState),
            logger: logger
        )
    }

    private func createXYKExchange(
        from host: HydraExchangeHostProtocol,
        registeringStateIn stateProviderRegistrar: AssetsExchangeStateRegistring
    ) -> AssetsHydraXYKExchange {
        let flowState = HydraXYKFlowState(
            account: host.selectedAccount,
            chain: host.chain,
            connection: host.connection,
            runtimeProvider: host.runtimeService,
            notificationsRegistrar: exchangeStateRegistrar,
            operationQueue: host.operationQueue
        )

        stateProviderRegistrar.addStateProvider(flowState)

        return AssetsHydraXYKExchange(
            host: host,
            tokensFactory: .init(
                chain: host.chain,
                runtimeService: host.runtimeService,
                connection: host.connection,
                operationQueue: host.operationQueue
            ),
            quoteFactory: .init(flowState: flowState),
            logger: logger
        )
    }

    private func createAaveExchange(
        from host: HydraExchangeHostProtocol,
        registeringStateIn stateProviderRegistrar: AssetsExchangeStateRegistring
    ) -> AssetsHydraAaveExchange {
        let flowState = HydraAaveFlowState(
            account: host.selectedAccount,
            connection: host.connection,
            runtimeProvider: host.runtimeService,
            notificationsRegistrar: exchangeStateRegistrar,
            operationQueue: operationQueue
        )

        stateProviderRegistrar.addStateProvider(flowState)

        return AssetsHydraAaveExchange(
            host: host,
            apiOperationFactory: HydraAaveTradeExecutorFactory(
                connection: host.connection,
                runtimeProvider: host.runtimeService,
                operationQueue: host.operationQueue
            ),
            quoteFactory: HydraAaveSwapQuoteFactory(flowState: flowState)
        )
    }

    // swiftlint:disable:next function_body_length
    private func setupHost(
        for chain: ChainModel,
        account: ChainAccountResponse,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol
    ) -> HydraExchangeHostProtocol {
        if let host = hosts[chain.chainId] {
            return host
        }

        let serviceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade
        )

        let customFeeEstimatingFactory = AssetExchangeFeeEstimatingFactory(
            graphProxy: graphProxy,
            operationQueue: operationQueue,
            feeBufferInPercentage: AssetExchangeFeeConstants.feeBufferInPercentage
        )

        let extrinsicOperationFactory = serviceFactory.createOperationFactory(
            account: account,
            chain: chain,
            customFeeEstimatingFactory: customFeeEstimatingFactory
        )

        let extrinsicService = serviceFactory.createService(
            account: account,
            chain: chain,
            customFeeEstimatingFactory: customFeeEstimatingFactory
        )

        let submissionMonitorFactory = ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicService,
            statusService: ExtrinsicStatusService(
                connection: connection,
                runtimeProvider: runtimeService,
                eventsQueryFactory: BlockEventsQueryFactory(
                    operationQueue: operationQueue,
                    logger: logger
                ),
                logger: logger
            ),
            operationQueue: operationQueue
        )

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: account.metaId,
            accountResponse: account
        )

        let swapParamsService = HydraSwapParamsService(
            accountId: account.accountId,
            connection: connection,
            runtimeProvider: runtimeService,
            operationQueue: operationQueue
        )

        swapParamsService.setup()

        let extrinsicParamsFactory = HydraExchangeExtrinsicParamsFactory(
            chain: chain,
            swapService: swapParamsService,
            runtimeProvider: runtimeService
        )

        let host = HydraExchangeHost(
            chain: chain,
            selectedAccount: account,
            submissionMonitorFactory: submissionMonitorFactory,
            extrinsicOperationFactory: extrinsicOperationFactory,
            extrinsicParamsFactory: extrinsicParamsFactory,
            runtimeService: runtimeService,
            connection: connection,
            signingWrapper: signingWrapper,
            executionTimeEstimator: AssetExchangeTimeEstimator(chainRegistry: chainRegistry),
            operationQueue: operationQueue,
            logger: logger
        )

        hosts[chain.chainId] = host

        return host
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

            let swapHost = setupHost(
                for: chain,
                account: selectedAccount,
                connection: connection,
                runtimeService: runtimeService
            )

            let omnipoolExchange = createOmnipoolExchange(from: swapHost, registeringStateIn: exchangeStateRegistrar)

            let stableswapExchange = createStableswapExchange(
                from: swapHost,
                registeringStateIn: exchangeStateRegistrar
            )

            let xykExchange = createXYKExchange(from: swapHost, registeringStateIn: exchangeStateRegistrar)

            let aaveExchange = createAaveExchange(from: swapHost, registeringStateIn: exchangeStateRegistrar)

            return [omnipoolExchange, stableswapExchange, xykExchange, aaveExchange]
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

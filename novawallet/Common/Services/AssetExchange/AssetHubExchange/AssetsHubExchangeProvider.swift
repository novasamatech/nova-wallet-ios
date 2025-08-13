import Foundation
import Operation_iOS

final class AssetsHubExchangeProvider: AssetsExchangeBaseProvider {
    private var supportedChains: [ChainModel.Id: ChainModel]?
    let wallet: MetaAccountModel
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let exchangeStateRegistrar: AssetsExchangeStateRegistring
    let userStorageFacade: StorageFacadeProtocol

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        pathCostEstimator: AssetsExchangePathCostEstimating,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        exchangeStateRegistrar: AssetsExchangeStateRegistring,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.signingWrapperFactory = signingWrapperFactory
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
        self.exchangeStateRegistrar = exchangeStateRegistrar

        super.init(
            chainRegistry: chainRegistry,
            pathCostEstimator: pathCostEstimator,
            operationQueue: operationQueue,
            syncQueue: DispatchQueue(label: "io.novawallet.assetshubprovider.\(UUID().uuidString)"),
            logger: logger
        )
    }

    private func updateStateIfNeeded() {
        guard let supportedChains else {
            return
        }

        let exchanges: [AssetsExchangeProtocol] = supportedChains.values.compactMap { chain in
            guard
                let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
                let connection = chainRegistry.getConnection(for: chain.chainId),
                let selectedAccount = wallet.fetch(for: chain.accountRequest()) else {
                logger.warning("Wallet, Connection or runtime unavailable for \(chain.name)")
                return nil
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
                account: selectedAccount,
                chain: chain,
                customFeeEstimatingFactory: customFeeEstimatingFactory
            )

            let extrinsicService = serviceFactory.createService(
                account: selectedAccount,
                chain: chain,
                customFeeEstimatingFactory: customFeeEstimatingFactory
            )

            let submissionMonitorFactory = ExtrinsicSubmissionMonitorFactory(
                submissionService: extrinsicService,
                statusService: ExtrinsicStatusService(
                    connection: connection,
                    runtimeProvider: runtimeService,
                    eventsQueryFactory: BlockEventsQueryFactory(operationQueue: operationQueue, logger: logger),
                    logger: logger
                ),
                operationQueue: operationQueue
            )

            let signingWrapper = signingWrapperFactory.createSigningWrapper(
                for: selectedAccount.metaId,
                accountResponse: selectedAccount
            )

            let flowState = AssetHubFlowState(
                connection: connection,
                runtimeProvider: runtimeService,
                notificationsRegistrar: exchangeStateRegistrar,
                operationQueue: operationQueue
            )

            exchangeStateRegistrar.addStateProvider(flowState)

            let host = AssetHubExchangeHost(
                chain: chain,
                selectedAccount: selectedAccount,
                flowState: flowState,
                submissionMonitorFactory: submissionMonitorFactory,
                extrinsicOperationFactory: extrinsicOperationFactory,
                signingWrapper: signingWrapper,
                runtimeService: runtimeService,
                connection: connection,
                executionTimeEstimator: AssetExchangeTimeEstimator(chainRegistry: chainRegistry),
                operationQueue: operationQueue,
                logger: logger
            )

            return AssetsHubExchange(host: host)
        }

        updateState(with: exchanges)
    }

    private func handleChains(changes: [DataProviderChange<ChainModel>]) -> Bool {
        let updatedChains = changes.reduce(into: supportedChains ?? [:]) { accum, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                accum[newItem.chainId] = newItem.hasSwapHub ? newItem : nil
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

import Foundation
import Keystore_iOS
import Operation_iOS
import SubstrateSdk

struct SubtensorStakingProcessServices {
    let bittensorApiOperationFactory: BittensorApiOperationFactoryProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let subnetMarketsService: SubtensorSubnetMarketsServiceProtocol
    let costBasisService: SubtensorCostBasisServiceProtocol
}

extension SubtensorStakingProcessServices {
    static let shared: SubtensorStakingProcessServices = {
        let apiOperationFactory = BittensorApiOperationFactory(
            transport: BittensorAuthorizedTransport.shared,
            cache: BittensorApiResponseCache(operationQueue: OperationManagerFacade.sharedDefaultQueue),
            logger: Logger.shared
        )

        return SubtensorStakingProcessServices(
            bittensorApiOperationFactory: apiOperationFactory,
            subnetLogosProvider: SubtensorConfigProvider(url: ApplicationConfig.shared.bittensorConfigURL),
            subnetMarketsService: SubtensorSubnetMarketsService(coingeckoOperationFactory: CoingeckoOperationFactory()),
            costBasisService: createCostBasisService(apiOperationFactory: apiOperationFactory)
        )
    }()

    func createMaxApyProvider(
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> SubtensorMaxApyProviderProtocol {
        SubtensorMaxApyProvider(
            apiOperationFactory: bittensorApiOperationFactory,
            yieldService: SubtensorYieldService(
                apiOperationFactory: bittensorApiOperationFactory,
                operationQueue: operationQueue,
                logger: logger
            ),
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func createCataloguePricingTracker(
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> SubtensorCataloguePricingTracker {
        SubtensorCataloguePricingTracker(
            catalogueService: SubtensorSubnetCatalogueService(
                apiOperationFactory: bittensorApiOperationFactory,
                logger: logger
            ),
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

private extension SubtensorStakingProcessServices {
    static func createCostBasisService(
        apiOperationFactory: BittensorApiOperationFactoryProtocol
    ) -> SubtensorCostBasisServiceProtocol {
        SubtensorCostBasisService(
            apiOperationFactory: apiOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared
        )
    }
}

extension StakingSharedStateFactory {
    func createSubtensorStaking(
        for stakingOption: Multistaking.ChainAssetOption,
        flowState: SubtensorStakingFlowStateProtocol
    ) throws -> SubtensorStakingSharedStateProtocol {
        let chainId = stakingOption.chainAsset.chain.chainId

        guard chainRegistry.getConnection(for: chainId) != nil else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard chainRegistry.getRuntimeProvider(for: chainId) != nil else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let runtimeConnectionStore = ChainRegistryRuntimeConnectionStore(chainId: chainId, chainRegistry: chainRegistry)

        let apiOperationFactory = SubtensorApiOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore, operationQueue: syncOperationQueue
        )

        let novaFeeCalculator = SubtensorNovaFeeCalculator()

        return SubtensorStakingSharedState(
            stakingOption: stakingOption,
            chainRegistry: chainRegistry,
            generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: storageFacade,
                operationManager: OperationManager(operationQueue: repositoryOperationQueue),
                logger: logger
            ),
            subnetsService: SubtensorSubnetsService(
                operationFactory: apiOperationFactory,
                operationQueue: syncOperationQueue
            ),
            apiOperationFactory: apiOperationFactory,
            stakeStateFetchFactory: SubtensorStakeStateFetchFactory(
                operationFactory: apiOperationFactory,
                operationQueue: syncOperationQueue
            ),
            earnServices: createSubtensorEarnServices(
                for: stakingOption,
                runtimeConnectionStore: runtimeConnectionStore,
                apiOperationFactory: apiOperationFactory,
                novaFeeCalculator: novaFeeCalculator,
                flowState: flowState
            ),
            flowState: flowState,
            eventCenter: eventCenter,
            operationQueue: syncOperationQueue,
            workingQueue: .global(),
            logger: logger,
            novaFeeCalculator: novaFeeCalculator
        )
    }

    private func createSubtensorEarnServices(
        for stakingOption: Multistaking.ChainAssetOption,
        runtimeConnectionStore: RuntimeConnectionStoring,
        apiOperationFactory: SubtensorApiOperationFactoryProtocol,
        novaFeeCalculator: SubtensorNovaFeeCalculator,
        flowState: SubtensorStakingFlowStateProtocol
    ) -> SubtensorEarnServices {
        let processServices = SubtensorStakingProcessServices.shared

        let validatorChainOperationFactory = SubtensorValidatorChainOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore, operationQueue: syncOperationQueue
        )

        let yieldService = SubtensorYieldService(
            apiOperationFactory: processServices.bittensorApiOperationFactory,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        let recommendationService = SubtensorRecommendationService(
            apiOperationFactory: processServices.bittensorApiOperationFactory,
            chainOperationFactory: validatorChainOperationFactory,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        let validatorDirectoryService = SubtensorValidatorDirectoryService(
            apiOperationFactory: processServices.bittensorApiOperationFactory,
            chainOperationFactory: validatorChainOperationFactory,
            cache: flowState.validatorDirectoryCache,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        return SubtensorEarnServices(
            subnetLogosProvider: processServices.subnetLogosProvider,
            earnSettings: SubtensorEarnSettings(settingsManager: SettingsManager.shared),
            catalogueService: SubtensorSubnetCatalogueService(
                apiOperationFactory: processServices.bittensorApiOperationFactory,
                logger: logger
            ),
            yieldService: yieldService,
            recommendationService: recommendationService,
            validatorDirectoryService: validatorDirectoryService,
            priceHistoryService: createSubtensorPriceHistoryService(
                for: stakingOption,
                marketsService: processServices.subnetMarketsService,
                seriesProvider: flowState.priceSeriesCache
            ),
            tradeQuoteFactory: SubtensorTradeQuoteFactory(
                quoteFactory: SubtensorQuoteOperationFactory(
                    operationFactory: apiOperationFactory,
                    operationQueue: syncOperationQueue
                ),
                feeCalculator: novaFeeCalculator
            ),
            rootHoldFactory: SubtensorRootHoldFactory(
                runtimeConnectionStore: runtimeConnectionStore, operationQueue: syncOperationQueue
            ),
            costBasisService: processServices.costBasisService
        )
    }

    private func createSubtensorPriceHistoryService(
        for stakingOption: Multistaking.ChainAssetOption,
        marketsService: SubtensorSubnetMarketsServiceProtocol,
        seriesProvider: SubtensorPriceSeriesProviding
    ) -> SubtensorPriceHistoryServiceProtocol? {
        guard let taoPriceId = stakingOption.chainAsset.asset.priceId else {
            return nil
        }

        return SubtensorPriceHistoryService(
            marketsService: marketsService,
            seriesProvider: seriesProvider,
            blockNumberOperationFactory: BlockNumberOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: syncOperationQueue
            ),
            chainId: stakingOption.chainAsset.chain.chainId,
            taoPriceId: taoPriceId,
            operationQueue: syncOperationQueue,
            logger: logger
        )
    }
}

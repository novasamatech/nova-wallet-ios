import Foundation
import SubstrateSdk
import Operation_iOS
import Keystore_iOS

struct SubtensorStakingProcessServices {
    let bittensorApiOperationFactory: BittensorApiOperationFactoryProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let subnetMarketsService: SubtensorSubnetMarketsServiceProtocol
    let maxApyResolution: SubtensorMaxApyResolution
    let costBasisService: SubtensorCostBasisServiceProtocol
    let isFixtureMode: Bool
}

struct SubtensorStakingChainServices {
    let apiOperationFactory: SubtensorApiOperationFactoryProtocol
    let subnetsService: SubtensorSubnetsServiceProtocol
    let quoteOperationFactory: SubtensorQuoteOperationFactoryProtocol
    let rootHoldFactory: SubtensorRootHoldFactoryProtocol
    let positionsSyncServiceFactory: ((AccountId) -> SubtensorPositionsSyncServiceProtocol)?
    let novaFeeCalculator: SubtensorNovaFeeCalculator
    let settingsManager: SettingsManagerProtocol
}

extension SubtensorStakingProcessServices {
    static let shared: SubtensorStakingProcessServices = {
        let isFixtureMode = isFixtureModeEnabled

        let apiOperationFactory = BittensorApiOperationFactory(
            transport: createTransport(isFixtureMode: isFixtureMode),
            cache: BittensorApiResponseCache(
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                logger: Logger.shared
            ),
            logger: Logger.shared
        )

        return SubtensorStakingProcessServices(
            bittensorApiOperationFactory: apiOperationFactory,
            subnetLogosProvider: SubtensorConfigProvider(url: ApplicationConfig.shared.bittensorConfigURL),
            subnetMarketsService: createSubnetMarketsService(),
            maxApyResolution: SubtensorMaxApyResolution(),
            costBasisService: createCostBasisService(apiOperationFactory: apiOperationFactory),
            isFixtureMode: isFixtureMode
        )
    }()

    func createValidatorChainOperationFactory(
        runtimeConnectionStore: RuntimeConnectionStoring
    ) -> SubtensorValidatorChainOperationFactoryProtocol {
        #if DEBUG
            if isFixtureMode {
                return BittensorFixtureChainSnapshot()
            }
        #endif

        return SubtensorValidatorChainOperationFactory(runtimeConnectionStore: runtimeConnectionStore)
    }

    func createMaxApyProvider(
        runtimeConnectionStore: RuntimeConnectionStoring,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> SubtensorMaxApyProviderProtocol {
        let recommendationService = SubtensorRecommendationService(
            apiOperationFactory: bittensorApiOperationFactory,
            chainOperationFactory: createValidatorChainOperationFactory(runtimeConnectionStore: runtimeConnectionStore),
            operationQueue: operationQueue,
            logger: logger
        )

        return createMaxApyProvider(
            recommendationService: recommendationService,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func createMaxApyProvider(
        recommendationService: SubtensorRecommendationServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> SubtensorMaxApyProviderProtocol {
        SubtensorMaxApyProvider(
            recommendationService: recommendationService,
            apiOperationFactory: bittensorApiOperationFactory,
            resolution: maxApyResolution,
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
    static var isFixtureModeEnabled: Bool {
        #if DEBUG
            BittensorApiFixtureMode.isEnabled
        #else
            false
        #endif
    }

    static func createTransport(isFixtureMode: Bool) -> BittensorApiTransportProtocol {
        #if DEBUG
            if isFixtureMode {
                return BittensorApiFixtureTransport()
            }

            if let baseURL = BittensorApiDirectMode.baseURL {
                return BittensorApiDirectTransport(baseURL: baseURL, logger: Logger.shared)
            }
        #endif

        return BittensorAttestedTransport.shared
    }

    static func createSubnetMarketsService() -> SubtensorSubnetMarketsServiceProtocol {
        SubtensorSubnetMarketsService(
            coingeckoOperationFactory: CoingeckoOperationFactory(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }

    static func createCostBasisService(
        apiOperationFactory: BittensorApiOperationFactoryProtocol
    ) -> SubtensorCostBasisServiceProtocol {
        SubtensorCostBasisService(
            apiOperationFactory: apiOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )
    }
}

extension StakingSharedStateFactory {
    func createSubtensorStaking(
        for stakingOption: Multistaking.ChainAssetOption,
        flowState: SubtensorStakingFlowStateProtocol
    ) throws -> SubtensorStakingSharedStateProtocol {
        try createSubtensorStaking(for: stakingOption, processServices: .shared, flowState: flowState)
    }

    func createSubtensorStaking(
        for stakingOption: Multistaking.ChainAssetOption,
        processServices: SubtensorStakingProcessServices,
        chainServices: SubtensorStakingChainServices? = nil,
        flowState: SubtensorStakingFlowStateProtocol
    ) throws -> SubtensorStakingSharedStateProtocol {
        let chainId = stakingOption.chainAsset.chain.chainId

        guard chainRegistry.getConnection(for: chainId) != nil else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard chainRegistry.getRuntimeProvider(for: chainId) != nil else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let runtimeConnectionStore = ChainRegistryRuntimeConnectionStore(
            chainId: stakingOption.chainAsset.chain.chainId,
            chainRegistry: chainRegistry
        )

        return createSubtensorSharedState(
            for: stakingOption,
            runtimeConnectionStore: runtimeConnectionStore,
            processServices: processServices,
            chainServices: chainServices ?? createChainServices(
                runtimeConnectionStore: runtimeConnectionStore,
                flowState: flowState
            ),
            flowState: flowState
        )
    }

    private func createChainServices(
        runtimeConnectionStore: RuntimeConnectionStoring,
        flowState: SubtensorStakingFlowStateProtocol
    ) -> SubtensorStakingChainServices {
        let apiOperationFactory = SubtensorApiOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore,
            operationQueue: syncOperationQueue
        )

        let subnetsService = SubtensorSubnetsService(
            operationFactory: apiOperationFactory,
            cache: flowState.subnetsInfoCache,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        return SubtensorStakingChainServices(
            apiOperationFactory: apiOperationFactory,
            subnetsService: subnetsService,
            quoteOperationFactory: SubtensorQuoteOperationFactory(
                operationFactory: apiOperationFactory,
                operationQueue: syncOperationQueue
            ),
            rootHoldFactory: SubtensorRootHoldFactory(runtimeConnectionStore: runtimeConnectionStore),
            positionsSyncServiceFactory: nil,
            novaFeeCalculator: SubtensorNovaFeeCalculator(),
            settingsManager: SettingsManager.shared
        )
    }

    private func createSubtensorSharedState(
        for stakingOption: Multistaking.ChainAssetOption,
        runtimeConnectionStore: RuntimeConnectionStoring,
        processServices: SubtensorStakingProcessServices,
        chainServices: SubtensorStakingChainServices,
        flowState: SubtensorStakingFlowStateProtocol
    ) -> SubtensorStakingSharedState {
        let stakeStateFetchFactory = SubtensorStakeStateFetchFactory(
            operationFactory: chainServices.apiOperationFactory,
            operationQueue: syncOperationQueue
        )

        let generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: repositoryOperationQueue),
            logger: logger
        )

        return SubtensorStakingSharedState(
            stakingOption: stakingOption,
            chainRegistry: chainRegistry,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            subnetsService: chainServices.subnetsService,
            apiOperationFactory: chainServices.apiOperationFactory,
            stakeStateFetchFactory: stakeStateFetchFactory,
            earnServices: createEarnServices(
                for: stakingOption,
                runtimeConnectionStore: runtimeConnectionStore,
                processServices: processServices,
                chainServices: chainServices,
                flowState: flowState
            ),
            flowState: flowState,
            eventCenter: eventCenter,
            operationQueue: syncOperationQueue,
            workingQueue: .global(),
            logger: logger,
            novaFeeCalculator: chainServices.novaFeeCalculator,
            positionsSyncServiceFactory: chainServices.positionsSyncServiceFactory
        )
    }

    private func createEarnServices(
        for stakingOption: Multistaking.ChainAssetOption,
        runtimeConnectionStore: RuntimeConnectionStoring,
        processServices: SubtensorStakingProcessServices,
        chainServices: SubtensorStakingChainServices,
        flowState: SubtensorStakingFlowStateProtocol
    ) -> SubtensorEarnServices {
        let validatorChainOperationFactory = processServices.createValidatorChainOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore
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
            earnSettings: SubtensorEarnSettings(settingsManager: chainServices.settingsManager),
            validatorChainOperationFactory: validatorChainOperationFactory,
            catalogueService: createCatalogueService(using: processServices),
            yieldService: yieldService,
            recommendationService: recommendationService,
            rankingViewService: createRankingViewService(for: recommendationService),
            validatorDirectoryService: validatorDirectoryService,
            priceHistoryService: createPriceHistoryService(
                for: stakingOption,
                marketsService: processServices.subnetMarketsService,
                seriesProvider: flowState.priceSeriesCache
            ),
            portfolioHistoryService: SubtensorPortfolioHistoryService(
                apiOperationFactory: processServices.bittensorApiOperationFactory
            ),
            tradeQuoteFactory: SubtensorTradeQuoteFactory(
                quoteFactory: chainServices.quoteOperationFactory,
                feeCalculator: chainServices.novaFeeCalculator
            ),
            rootHoldFactory: chainServices.rootHoldFactory,
            costBasisService: processServices.costBasisService
        )
    }

    private func createCatalogueService(
        using processServices: SubtensorStakingProcessServices
    ) -> SubtensorSubnetCatalogueServiceProtocol {
        SubtensorSubnetCatalogueService(
            apiOperationFactory: processServices.bittensorApiOperationFactory,
            logger: logger
        )
    }

    private func createRankingViewService(
        for recommendationService: SubtensorRecommendationServiceProtocol
    ) -> SubtensorRankingViewServiceProtocol {
        SubtensorRankingViewService(recommendationService: recommendationService, logger: logger)
    }

    private func createPriceHistoryService(
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

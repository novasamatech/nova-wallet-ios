import Foundation
import SubstrateSdk
import Operation_iOS
import Keystore_iOS

struct SubtensorStakingProcessServices {
    let bittensorApiOperationFactory: BittensorApiOperationFactoryProtocol
    let earnConfigProvider: SubtensorEarnConfigProviderProtocol
    let isFixtureMode: Bool
}

struct SubtensorStakingChainServices {
    let apiOperationFactory: SubtensorApiOperationFactoryProtocol
    let subnetsService: SubtensorSubnetsServiceProtocol
    let rewardCalculatorService: SubtensorRewardCalculatorServiceProtocol
    let quoteOperationFactory: SubtensorQuoteOperationFactoryProtocol
    let rootHoldFactory: SubtensorRootHoldFactoryProtocol
    let positionsSyncServiceFactory: ((AccountId) -> SubtensorPositionsSyncServiceProtocol)?
    let novaFeeCalculator: SubtensorNovaFeeCalculator
    let settingsManager: SettingsManagerProtocol
}

extension SubtensorStakingProcessServices {
    static let sharedEarnConfigProvider: SubtensorEarnConfigProviderProtocol = SubtensorEarnConfigProvider(
        configURL: ApplicationConfig.shared.subtensorEarnConfigURL,
        operationQueue: OperationManagerFacade.sharedDefaultQueue,
        logger: Logger.shared
    )

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
            earnConfigProvider: sharedEarnConfigProvider,
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
        #endif

        return BittensorAttestedTransport.shared
    }
}

extension StakingSharedStateFactory {
    func createSubtensorStaking(
        for stakingOption: Multistaking.ChainAssetOption
    ) throws -> SubtensorStakingSharedStateProtocol {
        try createSubtensorStaking(for: stakingOption, processServices: .shared)
    }

    func createSubtensorStaking(
        for stakingOption: Multistaking.ChainAssetOption,
        processServices: SubtensorStakingProcessServices,
        chainServices: SubtensorStakingChainServices? = nil
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
            chainServices: chainServices ?? createChainServices(runtimeConnectionStore: runtimeConnectionStore)
        )
    }

    private func createChainServices(
        runtimeConnectionStore: RuntimeConnectionStoring
    ) -> SubtensorStakingChainServices {
        let apiOperationFactory = SubtensorApiOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore,
            operationQueue: syncOperationQueue
        )

        let subnetsService = SubtensorSubnetsService(
            operationFactory: apiOperationFactory,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        return SubtensorStakingChainServices(
            apiOperationFactory: apiOperationFactory,
            subnetsService: subnetsService,
            rewardCalculatorService: createRewardCalculatorService(
                subnetsService: subnetsService,
                runtimeConnectionStore: runtimeConnectionStore
            ),
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
        chainServices: SubtensorStakingChainServices
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
            delegatesService: createDelegatesService(
                for: stakingOption,
                runtimeConnectionStore: runtimeConnectionStore
            ),
            rewardCalculatorService: chainServices.rewardCalculatorService,
            apiOperationFactory: chainServices.apiOperationFactory,
            stakeStateFetchFactory: stakeStateFetchFactory,
            earnServices: createEarnServices(
                for: stakingOption,
                runtimeConnectionStore: runtimeConnectionStore,
                processServices: processServices,
                chainServices: chainServices
            ),
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
        chainServices: SubtensorStakingChainServices
    ) -> SubtensorEarnServices {
        let validatorChainOperationFactory = processServices.createValidatorChainOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore
        )

        let yieldService = SubtensorYieldService(
            apiOperationFactory: processServices.bittensorApiOperationFactory,
            rewardCalculatorService: chainServices.rewardCalculatorService,
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
            earnConfigProvider: processServices.earnConfigProvider,
            recommendationService: recommendationService,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        return SubtensorEarnServices(
            earnConfigProvider: processServices.earnConfigProvider,
            earnSettings: SubtensorEarnSettings(settingsManager: chainServices.settingsManager),
            validatorChainOperationFactory: validatorChainOperationFactory,
            yieldService: yieldService,
            recommendationService: recommendationService,
            validatorDirectoryService: validatorDirectoryService,
            discoveryService: SubtensorDiscoveryService(
                yieldService: yieldService,
                directoryService: validatorDirectoryService,
                recommendationService: recommendationService,
                operationQueue: syncOperationQueue,
                logger: logger
            ),
            priceHistoryService: createPriceHistoryService(
                for: stakingOption,
                earnConfigProvider: processServices.earnConfigProvider
            ),
            tradeQuoteFactory: SubtensorTradeQuoteFactory(
                quoteFactory: chainServices.quoteOperationFactory,
                feeCalculator: chainServices.novaFeeCalculator
            ),
            rootHoldFactory: chainServices.rootHoldFactory
        )
    }

    private func createPriceHistoryService(
        for stakingOption: Multistaking.ChainAssetOption,
        earnConfigProvider: SubtensorEarnConfigProviderProtocol
    ) -> SubtensorPriceHistoryServiceProtocol? {
        guard let taoPriceId = stakingOption.chainAsset.asset.priceId else {
            return nil
        }

        return SubtensorPriceHistoryService(
            earnConfigProvider: earnConfigProvider,
            coingeckoOperationFactory: CoingeckoOperationFactory(),
            taoPriceId: taoPriceId,
            operationQueue: syncOperationQueue,
            logger: logger
        )
    }

    private func createRewardCalculatorService(
        subnetsService: SubtensorSubnetsServiceProtocol,
        runtimeConnectionStore: RuntimeConnectionStoring
    ) -> SubtensorRewardCalculatorService {
        let inputsService = SubtensorRootAprInputsService(
            operationFactory: SubtensorRootAprOperationFactory(
                runtimeConnectionStore: runtimeConnectionStore,
                operationQueue: syncOperationQueue
            ),
            operationQueue: syncOperationQueue,
            logger: logger
        )

        return SubtensorRewardCalculatorService(
            subnetsService: subnetsService,
            inputsService: inputsService,
            logger: logger
        )
    }

    private func createDelegatesService(
        for stakingOption: Multistaking.ChainAssetOption,
        runtimeConnectionStore: RuntimeConnectionStoring
    ) -> SubtensorDelegatesService {
        let delegatesOperationFactory = SubtensorApiOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore,
            operationQueue: syncOperationQueue,
            rpcTimeout: JSONRPCTimeout.hour
        )

        let identityProxyFactory = IdentityProxyFactory(
            originChain: stakingOption.chainAsset.chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: IdentityOperationFactory(
                requestFactory: StorageRequestFactory.createDefault(with: syncOperationQueue)
            )
        )

        return SubtensorDelegatesService(
            operationFactory: delegatesOperationFactory,
            identityProxyFactory: identityProxyFactory,
            operationQueue: syncOperationQueue,
            logger: logger
        )
    }
}

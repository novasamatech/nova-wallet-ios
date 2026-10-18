import Foundation
import Keystore_iOS
import Operation_iOS
import SubstrateSdk

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
            stakeStateSourceFactory: SubtensorStakingProcessServices.shared.stakeStateSourceFactory,
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

    // swiftlint:disable:next function_body_length
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

        let yieldService = processServices.createYieldService(operationQueue: syncOperationQueue, logger: logger)

        let recommendationService = SubtensorRecommendationService(
            apiOperationFactory: processServices.bittensorApiOperationFactory,
            chainOperationFactory: validatorChainOperationFactory,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        let validatorDirectoryService = SubtensorValidatorDirectoryService(
            apiOperationFactory: processServices.bittensorApiOperationFactory,
            chainOperationFactory: validatorChainOperationFactory,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        return SubtensorEarnServices(
            subnetLogosProvider: processServices.subnetLogosProvider,
            earnSettings: SubtensorEarnSettings(settingsManager: SettingsManager.shared),
            catalogueService: processServices.catalogueService,
            alphaPriceProvider: processServices.createAlphaPriceProvider(
                chainOperationFactory: apiOperationFactory, operationQueue: syncOperationQueue, logger: logger
            ),
            yieldService: yieldService,
            maxApyProvider: processServices.createMaxApyProvider(operationQueue: syncOperationQueue, logger: logger),
            recommendationService: recommendationService,
            validatorDirectoryService: validatorDirectoryService,
            priceHistoryService: createSubtensorPriceHistoryService(
                for: stakingOption, runtimeConnectionStore: runtimeConnectionStore, flowState: flowState
            ),
            tradeQuoteFactory: SubtensorTradeQuoteFactory(
                operationFactory: apiOperationFactory,
                configProvider: processServices.subnetLogosProvider,
                operationQueue: syncOperationQueue,
                feeCalculator: novaFeeCalculator
            ),
            rootHoldFactory: SubtensorRootHoldFactory(
                runtimeConnectionStore: runtimeConnectionStore, operationQueue: syncOperationQueue,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: stakingOption.chainAsset.chain)
            ),
            groupHotkeyFactory: SubtensorGroupHotkeyFactory(
                runtimeConnectionStore: runtimeConnectionStore, operationQueue: syncOperationQueue
            ),
            validatorPresetFactory: SubtensorValidatorPresetFactory(
                directoryService: validatorDirectoryService,
                recommendationService: recommendationService,
                yieldService: yieldService,
                operationQueue: syncOperationQueue,
                logger: logger
            ),
            costBasisService: processServices.costBasisService
        )
    }

    private func createSubtensorPriceHistoryService(
        for stakingOption: Multistaking.ChainAssetOption,
        runtimeConnectionStore: RuntimeConnectionStoring,
        flowState: SubtensorStakingFlowStateProtocol
    ) -> SubtensorPriceHistoryServiceProtocol? {
        guard let taoPriceId = stakingOption.chainAsset.asset.priceId else {
            return nil
        }

        let processServices = SubtensorStakingProcessServices.shared

        return SubtensorPriceHistoryService(
            marketsService: processServices.subnetMarketsService,
            apiOperationFactory: processServices.bittensorApiOperationFactory,
            coingeckoOperationFactory: flowState.coingeckoOperationFactory,
            blockNumberOperationFactory: BlockNumberOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: syncOperationQueue
            ),
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: stakingOption.chainAsset.chain),
            runtimeConnectionStore: runtimeConnectionStore,
            chainId: stakingOption.chainAsset.chain.chainId,
            taoPriceId: taoPriceId,
            operationQueue: syncOperationQueue,
            logger: logger
        )
    }
}

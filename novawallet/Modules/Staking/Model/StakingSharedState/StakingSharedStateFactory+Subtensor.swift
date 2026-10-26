import Foundation
import Keystore_iOS
import Operation_iOS
import SubstrateSdk

extension StakingSharedStateFactory {
    func createSubtensorStaking(
        for stakingOption: Multistaking.ChainAssetOption,
        flowState: SubtensorFlowStateProtocol
    ) throws -> SubtensorSharedStateProtocol {
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

        return SubtensorSharedState(
            stakingOption: stakingOption,
            chainRegistry: chainRegistry,
            generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: storageFacade,
                operationManager: OperationManager(operationQueue: repositoryOperationQueue),
                logger: logger
            ),
            subnetsOperationFactory: SubtensorSubnetsOperationFactory(
                operationFactory: apiOperationFactory,
                operationQueue: syncOperationQueue
            ),
            apiOperationFactory: apiOperationFactory,
            stakeStateSourceFactory: SubtensorProcessServices.shared.stakeStateSourceFactory,
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
        flowState: SubtensorFlowStateProtocol
    ) -> SubtensorEarnServices {
        let processServices = SubtensorProcessServices.shared

        let validatorChainOperationFactory = SubtensorValidatorChainOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore, operationQueue: syncOperationQueue
        )

        let yieldOperationFactory = processServices.createYieldOperationFactory(
            operationQueue: syncOperationQueue, logger: logger
        )

        let recommendationOperationFactory = SubtensorRecommendationOperationFactory(
            apiOperationFactory: processServices.bittensorApiOperationFactory,
            chainOperationFactory: validatorChainOperationFactory,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        let validatorDirectoryOperationFactory = SubtensorValidatorDirectoryOperationFactory(
            apiOperationFactory: processServices.bittensorApiOperationFactory,
            chainOperationFactory: validatorChainOperationFactory,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        return SubtensorEarnServices(
            subnetLogosProvider: processServices.subnetLogosProvider,
            earnSettings: SubtensorEarnSettings(settingsManager: SettingsManager.shared),
            catalogueOperationFactory: processServices.catalogueOperationFactory,
            alphaPriceOperationFactory: processServices.createAlphaPriceOperationFactory(
                chainOperationFactory: apiOperationFactory, operationQueue: syncOperationQueue, logger: logger
            ),
            yieldOperationFactory: yieldOperationFactory,
            maxApyOperationFactory: processServices.createMaxApyOperationFactory(
                operationQueue: syncOperationQueue, logger: logger
            ),
            recommendationOperationFactory: recommendationOperationFactory,
            validatorDirectoryOperationFactory: validatorDirectoryOperationFactory,
            validatorChainOperationFactory: validatorChainOperationFactory,
            priceHistoryOperationFactory: createSubtensorPriceHistoryOperationFactory(
                for: stakingOption, flowState: flowState
            ),
            tradeQuoteOperationFactory: SubtensorTradeQuoteOperationFactory(
                operationFactory: apiOperationFactory,
                configProvider: processServices.subnetLogosProvider,
                operationQueue: syncOperationQueue,
                feeCalculator: novaFeeCalculator
            ),
            rootHoldOperationFactory: SubtensorRootHoldOperationFactory(
                runtimeConnectionStore: runtimeConnectionStore, operationQueue: syncOperationQueue,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: stakingOption.chainAsset.chain)
            ),
            groupHotkeyOperationFactory: SubtensorGroupHotkeyOperationFactory(
                runtimeConnectionStore: runtimeConnectionStore, operationQueue: syncOperationQueue
            ),
            validatorPresetOperationFactory: SubtensorValidatorPresetOperationFactory(
                directoryOperationFactory: validatorDirectoryOperationFactory,
                recommendationOperationFactory: recommendationOperationFactory,
                yieldOperationFactory: yieldOperationFactory,
                operationQueue: syncOperationQueue,
                logger: logger
            ),
            costBasisService: processServices.costBasisService
        )
    }

    private func createSubtensorPriceHistoryOperationFactory(
        for stakingOption: Multistaking.ChainAssetOption,
        flowState: SubtensorFlowStateProtocol
    ) -> SubtensorPriceHistoryOperationFactoryProtocol? {
        guard let taoPriceId = stakingOption.chainAsset.asset.priceId else {
            return nil
        }

        let processServices = SubtensorProcessServices.shared

        return SubtensorPriceHistoryOperationFactory(
            marketsOperationFactory: processServices.subnetMarketsOperationFactory,
            apiOperationFactory: processServices.bittensorApiOperationFactory,
            coingeckoOperationFactory: flowState.coingeckoOperationFactory,
            taoPriceId: taoPriceId,
            operationQueue: syncOperationQueue,
            logger: logger
        )
    }
}

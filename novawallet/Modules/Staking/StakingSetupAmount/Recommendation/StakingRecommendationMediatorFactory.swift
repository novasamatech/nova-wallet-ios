import Foundation
import SubstrateSdk
import RobinHood

protocol StakingRecommendationMediatorFactoryProtocol {
    func createDirectStakingMediator(
        for state: RelaychainStartStakingStateProtocol
    ) -> RelaychainStakingRecommendationMediating?

    func createPoolStakingMediator(
        for state: RelaychainStartStakingStateProtocol
    ) -> RelaychainStakingRecommendationMediating?

    func createHybridStakingMediator(
        for state: RelaychainStartStakingStateProtocol
    ) -> RelaychainStakingRecommendationMediating?
}

final class StakingRecommendationMediatorFactory {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    private func createDirectStakingRecommendationFactory(
        for state: RelaychainStartStakingStateProtocol
    ) -> DirectStakingRecommendationFactoryProtocol? {
        let chainId = state.chainAsset.chain.chainId

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId) else {
            return nil
        }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: storageRequestFactory
        )

        let validatorOperationFactory = ValidatorOperationFactory(
            chainInfo: state.chainAsset.chainAssetInfo,
            eraValidatorService: state.eraValidatorService,
            rewardService: state.relaychainRewardCalculatorService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: identityOperationFactory
        )

        return DirectStakingRecommendationFactory(
            runtimeProvider: runtimeService,
            operationFactory: validatorOperationFactory,
            defaultMaxNominations: SubstrateConstants.maxNominations,
            clusterLimit: StakingConstants.targetsClusterLimit
        )
    }

    private func createDirectStakingRestrictionsBuilder(
        for state: RelaychainStartStakingStateProtocol
    ) -> DirectStakingRestrictionsBuilder? {
        let networkInfoFactory = state.createNetworkInfoOperationFactory(for: operationQueue)

        let chainId = state.chainAsset.chain.chainId

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return nil
        }

        return DirectStakingRestrictionsBuilder(
            chainAsset: state.chainAsset,
            stakingLocalSubscriptionFactory: state.relaychainLocalSubscriptionFactory,
            networkInfoFactory: networkInfoFactory,
            eraValidatorService: state.eraValidatorService,
            runtimeService: runtimeService,
            operationQueue: operationQueue
        )
    }
}

extension StakingRecommendationMediatorFactory: StakingRecommendationMediatorFactoryProtocol {
    func createDirectStakingMediator(
        for state: RelaychainStartStakingStateProtocol
    ) -> RelaychainStakingRecommendationMediating? {
        guard
            let recommendationFactory = createDirectStakingRecommendationFactory(for: state),
            let restrictionsBuilder = createDirectStakingRestrictionsBuilder(for: state) else {
            return nil
        }

        return DirectStakingRecommendationMediator(
            recommendationFactory: recommendationFactory,
            restrictionsBuilder: restrictionsBuilder,
            operationQueue: operationQueue
        )
    }

    func createPoolStakingMediator(
        for state: RelaychainStartStakingStateProtocol
    ) -> RelaychainStakingRecommendationMediating? {
        let restrictionsBuilder = PoolStakingRestrictionsBuilder(
            chainAsset: state.chainAsset,
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory
        )

        let chainId = state.chainAsset.chain.chainId

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return nil
        }

        guard let activePoolService = state.activePoolsService else {
            return nil
        }

        let poolsOperationFactory = NominationPoolsOperationFactory(operationQueue: operationQueue)

        let rewardCalculationFactory = NPoolsRewardEngineFactory(operationFactory: poolsOperationFactory)

        let operationFactory = NominationPoolRecommendationFactory(
            eraPoolsService: activePoolService,
            validatorRewardService: state.relaychainRewardCalculatorService,
            rewardEngineOperationFactory: rewardCalculationFactory,
            connection: connection,
            runtimeService: runtimeService,
            storageOperationFactory: poolsOperationFactory
        )

        return PoolStakingRecommendationMediator(
            chainAsset: state.chainAsset,
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory,
            restrictionsBuilder: restrictionsBuilder,
            operationFactory: operationFactory,
            operationQueue: operationQueue
        )
    }

    func createHybridStakingMediator(
        for state: RelaychainStartStakingStateProtocol
    ) -> RelaychainStakingRecommendationMediating? {
        guard
            let directStakingRestrictionsBuilder = createDirectStakingRestrictionsBuilder(for: state),
            let directStakingMediator = createDirectStakingMediator(for: state),
            let poolMediator = createPoolStakingMediator(for: state) else {
            return nil
        }

        return HybridStakingRecommendationMediator(
            chainAsset: state.chainAsset,
            directStakingMediator: directStakingMediator,
            nominationPoolsMediator: poolMediator,
            directStakingRestrictionsBuilder: directStakingRestrictionsBuilder
        )
    }
}

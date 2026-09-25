import Foundation
import SubstrateSdk
import Operation_iOS

extension StakingSharedStateFactory {
    func createSubtensorStaking(
        for stakingOption: Multistaking.ChainAssetOption
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

        let apiOperationFactory = SubtensorApiOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore,
            operationQueue: syncOperationQueue
        )

        let stakeStateFetchFactory = SubtensorStakeStateFetchFactory(
            operationFactory: apiOperationFactory,
            operationQueue: syncOperationQueue
        )

        let generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: repositoryOperationQueue),
            logger: logger
        )

        let subnetsService = SubtensorSubnetsService(
            operationFactory: apiOperationFactory,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        return SubtensorStakingSharedState(
            stakingOption: stakingOption,
            chainRegistry: chainRegistry,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            subnetsService: subnetsService,
            delegatesService: createDelegatesService(
                for: stakingOption,
                runtimeConnectionStore: runtimeConnectionStore
            ),
            rewardCalculatorService: createRewardCalculatorService(
                subnetsService: subnetsService,
                runtimeConnectionStore: runtimeConnectionStore
            ),
            apiOperationFactory: apiOperationFactory,
            stakeStateFetchFactory: stakeStateFetchFactory,
            operationQueue: syncOperationQueue,
            workingQueue: .global(),
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

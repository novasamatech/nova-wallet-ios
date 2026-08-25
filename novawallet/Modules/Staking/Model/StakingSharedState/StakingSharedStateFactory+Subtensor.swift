import Foundation
import SubstrateSdk
import Operation_iOS

extension StakingSharedStateFactory {
    func createSubtensorStaking(
        for stakingOption: Multistaking.ChainAssetOption
    ) throws -> SubtensorStakingSharedStateProtocol {
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

        return SubtensorStakingSharedState(
            stakingOption: stakingOption,
            chainRegistry: chainRegistry,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            subnetsService: SubtensorSubnetsService(
                operationFactory: apiOperationFactory,
                operationQueue: syncOperationQueue,
                logger: logger
            ),
            delegatesService: createDelegatesService(
                for: stakingOption,
                runtimeConnectionStore: runtimeConnectionStore
            ),
            apiOperationFactory: apiOperationFactory,
            stakeStateFetchFactory: stakeStateFetchFactory,
            operationQueue: syncOperationQueue,
            workingQueue: .global(),
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

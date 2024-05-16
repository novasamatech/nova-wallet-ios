import Foundation
import RobinHood
import SubstrateSdk

final class GovernanceDelegateListOperationFactory {
    let statsOperationFactory: GovernanceDelegateStatsFactoryProtocol
    let metadataOperationFactory: GovernanceDelegateMetadataFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    
    init(
        statsOperationFactory: GovernanceDelegateStatsFactoryProtocol,
        metadataOperationFactory: GovernanceDelegateMetadataFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) {
        self.statsOperationFactory = statsOperationFactory
        self.metadataOperationFactory = metadataOperationFactory
        self.chainRegistry = chainRegistry
        self.identityOperationFactory = identityOperationFactory
    }

    private func createIdentityWrapper(
        dependingOn statsOperation: BaseOperation<[GovernanceDelegateStats]>,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[AccountId: AccountIdentity]> {
        IdentityProxyFactory(
            originChain: chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        ).createIdentityWrapperByAccountId(
            for: {
                let stats = try statsOperation.extractNoCancellableResultData()
                return try stats.map { try $0.address.toAccountId() }
            }
        )
    }

    private func createMergeOperation(
        dependingOn statsOperation: BaseOperation<[GovernanceDelegateStats]>,
        metadataOperation: BaseOperation<[GovernanceDelegateMetadataRemote]>,
        identitiesOperation: BaseOperation<[AccountId: AccountIdentity]>
    ) -> BaseOperation<[GovernanceDelegateLocal]> {
        ClosureOperation<[GovernanceDelegateLocal]> {
            let stats = try statsOperation.extractNoCancellableResultData()
            let metadataList = try? metadataOperation.extractNoCancellableResultData()
            let identities = try? identitiesOperation.extractNoCancellableResultData()

            let initMetadataStore = [AccountId: GovernanceDelegateMetadataRemote]()
            let metadataStore = try metadataList?.reduce(into: initMetadataStore) { accum, item in
                let accountId = try item.address.toAccountId()
                accum[accountId] = item
            }

            return try stats.map { statsItem in
                let accountId = try statsItem.address.toAccountId()
                let metadata = metadataStore?[accountId]
                let identity = identities?[accountId]

                return GovernanceDelegateLocal(stats: statsItem, metadata: metadata, identity: identity)
            }
        }
    }

    private func createDelegateListWrapper(
        from statsWrapper: CompoundOperationWrapper<[GovernanceDelegateStats]>,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]> {
        let metadataOperation = metadataOperationFactory.fetchMetadataOperation(for: chain)

        let identityWrapper = createIdentityWrapper(
            dependingOn: statsWrapper.targetOperation,
            chain: chain
        )

        identityWrapper.addDependency(wrapper: statsWrapper)

        let mergeOperation = createMergeOperation(
            dependingOn: statsWrapper.targetOperation,
            metadataOperation: metadataOperation,
            identitiesOperation: identityWrapper.targetOperation
        )

        mergeOperation.addDependency(identityWrapper.targetOperation)
        mergeOperation.addDependency(statsWrapper.targetOperation)
        mergeOperation.addDependency(metadataOperation)

        let dependencies = statsWrapper.allOperations + identityWrapper.allOperations + [metadataOperation]

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}

extension GovernanceDelegateListOperationFactory: GovernanceDelegateListFactoryProtocol {
    func fetchDelegateListWrapper(
        for activityStartBlock: BlockNumber,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]> {
        let statsWrapper = statsOperationFactory.fetchStatsWrapper(for: activityStartBlock)

        return createDelegateListWrapper(
            from: statsWrapper,
            chain: chain,
            connection: connection,
            runtimeService: runtimeService
        )
    }

    func fetchDelegateListByIdsWrapper(
        from delegateIds: Set<AccountId>,
        activityStartBlock: BlockNumber,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]> {
        let addresses = delegateIds.compactMap { accountId in
            try? accountId.toAddress(using: chain.chainFormat)
        }

        let statsWrapper = statsOperationFactory.fetchStatsByIdsWrapper(
            from: Set(addresses),
            activityStartBlock: activityStartBlock
        )

        return createDelegateListWrapper(
            from: statsWrapper,
            chain: chain,
            connection: connection,
            runtimeService: runtimeService
        )
    }
}

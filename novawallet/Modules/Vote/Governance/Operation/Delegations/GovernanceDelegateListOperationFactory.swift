import Foundation
import Operation_iOS
import SubstrateSdk

final class GovernanceDelegateListOperationFactory {
    let statsOperationFactory: GovernanceDelegateStatsFactoryProtocol
    let metadataOperationFactory: GovernanceDelegateMetadataFactoryProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let chain: ChainModel

    init(
        chain: ChainModel,
        statsOperationFactory: GovernanceDelegateStatsFactoryProtocol,
        metadataOperationFactory: GovernanceDelegateMetadataFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol
    ) {
        self.chain = chain
        self.statsOperationFactory = statsOperationFactory
        self.metadataOperationFactory = metadataOperationFactory
        self.identityProxyFactory = identityProxyFactory
    }

    private func createIdentityWrapper(
        dependingOn statsOperation: BaseOperation<[GovernanceDelegateStats]>
    ) -> CompoundOperationWrapper<[AccountId: AccountIdentity]> {
        identityProxyFactory.createIdentityWrapperByAccountId(
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
        from statsWrapper: CompoundOperationWrapper<[GovernanceDelegateStats]>
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]> {
        let metadataOperation = metadataOperationFactory.fetchMetadataOperation(for: chain)

        let identityWrapper = createIdentityWrapper(
            dependingOn: statsWrapper.targetOperation
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
        for threshold: TimepointThreshold
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]> {
        let statsWrapper = statsOperationFactory.fetchStatsWrapper(for: threshold)

        return createDelegateListWrapper(from: statsWrapper)
    }

    func fetchDelegateListByIdsWrapper(
        from delegateIds: Set<AccountId>,
        threshold: TimepointThreshold
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]> {
        let addresses = delegateIds.compactMap { accountId in
            try? accountId.toAddress(using: chain.chainFormat)
        }

        let statsWrapper = statsOperationFactory.fetchStatsByIdsWrapper(
            from: Set(addresses),
            threshold: threshold
        )

        return createDelegateListWrapper(from: statsWrapper)
    }
}

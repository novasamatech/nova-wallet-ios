import Foundation
import RobinHood
import SubstrateSdk

final class GovernanceDelegateListOperationFactory {
    let statsOperationFactory: GovernanceDelegateStatsFactoryProtocol
    let metadataOperationFactory: GovernanceDelegateMetadataFactoryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol

    init(
        statsOperationFactory: GovernanceDelegateStatsFactoryProtocol,
        metadataOperationFactory: GovernanceDelegateMetadataFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) {
        self.statsOperationFactory = statsOperationFactory
        self.metadataOperationFactory = metadataOperationFactory
        self.identityOperationFactory = identityOperationFactory
    }

    private func createIdentityWrapper(
        dependingOn statsOperation: BaseOperation<[GovernanceDelegateStats]>,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[AccountId: AccountIdentity]> {
        identityOperationFactory.createIdentityWrapperByAccountId(
            for: {
                let stats = try statsOperation.extractNoCancellableResultData()
                return try stats.map { try $0.address.toAccountId() }
            },
            engine: connection,
            runtimeService: runtimeService,
            chainFormat: chain.chainFormat
        )
    }

    private func createMergeOperation(
        dependingOn statsOperation: BaseOperation<[GovernanceDelegateStats]>,
        metadataOperation: BaseOperation<[GovernanceDelegateMetadataRemote]>,
        identitiesOperation: BaseOperation<[AccountId: AccountIdentity]>
    ) -> BaseOperation<[GovernanceDelegateLocal]> {
        ClosureOperation<[GovernanceDelegateLocal]> {
            let stats = try statsOperation.extractNoCancellableResultData()
            let metadataList = try metadataOperation.extractNoCancellableResultData()
            let identities = try? identitiesOperation.extractNoCancellableResultData()

            let initMetadataStore = [AccountId: GovernanceDelegateMetadataRemote]()
            let metadataStore = try metadataList.reduce(into: initMetadataStore) { accum, item in
                let accountId = try item.address.toAccountId()
                accum[accountId] = item
            }

            return try stats.map { statsItem in
                let accountId = try statsItem.address.toAccountId()
                let metadata = metadataStore[accountId]
                let identity = identities?[accountId]

                return GovernanceDelegateLocal(stats: statsItem, metadata: metadata, identity: identity)
            }
        }
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
        let metadataOperation = metadataOperationFactory.fetchMetadataOperation(for: chain)

        let identityWrapper = createIdentityWrapper(
            dependingOn: statsWrapper.targetOperation,
            chain: chain,
            connection: connection,
            runtimeService: runtimeService
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

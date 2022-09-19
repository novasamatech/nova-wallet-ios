import RobinHood

final class CrowdloanOffChainSyncService: BaseSyncService {
    private let source: ExternalContributionSourceProtocol
    private let operationManager: OperationManagerProtocol
    private let repository: AnyDataProviderRepository<CrowdloanContributionData>
    private var syncOperationWrapper: CompoundOperationWrapper<Void>?
    private let chain: ChainModel
    private let accountId: AccountId

    init(
        source: ExternalContributionSourceProtocol,
        chain: ChainModel,
        accountId: AccountId,
        operationManager: OperationManagerProtocol,
        repository: AnyDataProviderRepository<CrowdloanContributionData>
    ) {
        self.source = source
        self.operationManager = operationManager
        self.repository = repository
        self.chain = chain
        self.accountId = accountId
    }

    private func contributionsFetchOperation(
        accountId: AccountId,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[ExternalContribution]> {
        source.getContributions(accountId: accountId, chain: chain)
    }

    private func createChangesOperationWrapper(
        dependingOn contributionsOperation: CompoundOperationWrapper<[ExternalContribution]>,
        chainId: ChainModel.Id,
        accountId: AccountId
    ) -> BaseOperation<[DataProviderChange<CrowdloanContributionData>]?> {
        let changesOperation = ClosureOperation<[DataProviderChange<CrowdloanContributionData>]?> {
            let contributions = try contributionsOperation.targetOperation.extractNoCancellableResultData()

            let remoteModels: [CrowdloanContributionData] = contributions.compactMap {
                CrowdloanContributionData(
                    accountId: accountId,
                    chainId: chainId,
                    paraId: $0.paraId,
                    source: $0.source,
                    amount: $0.amount
                )
            }

            return remoteModels.map(DataProviderChange.update)
        }

        changesOperation.addDependency(contributionsOperation.targetOperation)

        return changesOperation
    }

    private func createSaveOperation(
        dependingOn operation: BaseOperation<[DataProviderChange<CrowdloanContributionData>]?>
    ) -> BaseOperation<Void> {
        let replaceOperation = repository.replaceOperation {
            guard let changes = try operation.extractNoCancellableResultData() else {
                return []
            }
            return changes.compactMap(\.item)
        }

        replaceOperation.addDependency(operation)
        return replaceOperation
    }

    override func performSyncUp() {
        let contributionsFetchOperation = contributionsFetchOperation(
            accountId: accountId,
            chain: chain
        )

        let changesWrapper = createChangesOperationWrapper(
            dependingOn: contributionsFetchOperation,
            chainId: chain.chainId,
            accountId: accountId
        )
        let saveOperation = createSaveOperation(dependingOn: changesWrapper)

        saveOperation.completionBlock = {
            guard !saveOperation.isCancelled else {
                return
            }

            do {
                try saveOperation.extractNoCancellableResultData()
                self.syncOperationWrapper = nil
                self.complete(nil)
            } catch {
                self.syncOperationWrapper = nil
                self.complete(error)
            }
        }

        let operations = contributionsFetchOperation.allOperations + [changesWrapper]

        let syncWrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: operations
        )

        syncOperationWrapper = syncWrapper
        operationManager.enqueue(operations: syncWrapper.allOperations, in: .transient)
    }

    override func stopSyncUp() {
        syncOperationWrapper?.cancel()
        syncOperationWrapper = nil
    }
}

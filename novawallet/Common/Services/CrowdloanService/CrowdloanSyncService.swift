import SubstrateSdk
import RobinHood

final class CrowdloanOnChainSyncService: BaseSyncService {
    private let operationFactory: CrowdloanOperationFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let operationManager: OperationManagerProtocol
    private let operationQueue: OperationQueue
    private let accountId: AccountId
    private let chainId: ChainModel.Id
    private let repository: AnyDataProviderRepository<CrowdloanContributionData>

    init(
        operationFactory: CrowdloanOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<CrowdloanContributionData>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        operationQueue: OperationQueue
    ) {
        self.operationFactory = operationFactory
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.repository = repository
        self.accountId = accountId
        self.chainId = chainId
        operationManager = OperationManager(operationQueue: operationQueue)
    }

    private func contributionsFetchOperation(
        dependingOn fetchCrowdloansOperation: CompoundOperationWrapper<[Crowdloan]>,
        connection: ChainConnection,
        runtimeService: RuntimeProviderProtocol,
        accountId: AccountId
    ) -> BaseOperation<[RemoteCrowdloanContribution]> {
        let contributionsOperation: BaseOperation<[RemoteCrowdloanContribution]> =
            OperationCombiningService(operationManager: operationManager) { [weak self] in
                guard let self = self else {
                    return []
                }

                let crowdloans = try fetchCrowdloansOperation.targetOperation.extractNoCancellableResultData()

                return crowdloans.map { crowdloan in
                    let fetchOperation = self.operationFactory.fetchContributionOperation(
                        connection: connection,
                        runtimeService: runtimeService,
                        accountId: accountId,
                        index: crowdloan.fundInfo.index
                    )

                    let mapOperation = ClosureOperation<RemoteCrowdloanContribution> {
                        let contributionResponse = try fetchOperation.targetOperation.extractNoCancellableResultData()

                        return RemoteCrowdloanContribution(
                            crowdloan: crowdloan,
                            contribution: contributionResponse.contribution
                        )
                    }

                    mapOperation.addDependency(fetchOperation.targetOperation)

                    return CompoundOperationWrapper(
                        targetOperation: mapOperation,
                        dependencies: fetchOperation.allOperations
                    )
                }
            }.longrunOperation()

        contributionsOperation.addDependency(fetchCrowdloansOperation.targetOperation)

        return contributionsOperation
    }

    private func createChangesOperationWrapper(
        dependingOn contributionsOperation: BaseOperation<[RemoteCrowdloanContribution]>,
        chainId: ChainModel.Id,
        accountId: AccountId
    ) -> BaseOperation<[DataProviderChange<CrowdloanContributionData>]?> {
        let changesOperation = ClosureOperation<[DataProviderChange<CrowdloanContributionData>]?> {
            let contributions = try contributionsOperation
                .extractNoCancellableResultData()

            let remoteModels: [CrowdloanContributionData] = contributions.compactMap {
                guard let contribution = $0.contribution else {
                    return nil
                }
                return CrowdloanContributionData(
                    accountId: accountId,
                    chainId: chainId,
                    paraId: $0.crowdloan.paraId,
                    source: nil,
                    amount: contribution.balance
                )
            }

            return remoteModels.map(DataProviderChange.update)
        }

        changesOperation.addDependency(contributionsOperation)

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
        guard let connection = chainRegistry.getConnection(for: chainId),
              let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger?.error("Sync is failed. Chain settings is invalid")
            return
        }
        let fetchCrowdloansOperation = operationFactory.fetchCrowdloansOperation(
            connection: connection,
            runtimeService: runtimeService
        )
        let contributionsFetchOperation = contributionsFetchOperation(
            dependingOn: fetchCrowdloansOperation,
            connection: connection,
            runtimeService: runtimeService,
            accountId: accountId
        )
        let changesWrapper = createChangesOperationWrapper(
            dependingOn: contributionsFetchOperation,
            chainId: chainId,
            accountId: accountId
        )
        let saveOperation = createSaveOperation(dependingOn: changesWrapper)

        let operations = fetchCrowdloansOperation.allOperations + [contributionsFetchOperation] + [changesWrapper] + [saveOperation]

        operationManager.enqueue(operations: operations, in: .transient)
    }

    override func stopSyncUp() {
        operationQueue.cancelAllOperations()
    }
}

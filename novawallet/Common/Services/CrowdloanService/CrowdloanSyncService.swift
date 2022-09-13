import SubstrateSdk
import RobinHood

protocol CrowdloanContributionOperationFactoryProtocol {
    func fetchCrowdloansOperation() -> CompoundOperationWrapper<[Crowdloan]>

    func fetchContributionOperation(
        accountId: AccountId,
        index: FundIndex
    ) -> CompoundOperationWrapper<CrowdloanContributionResponse>
}

final class CrowdloanContributionOperationFactory: CrowdloanContributionOperationFactoryProtocol {
    let factory: CrowdloanOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol

    init(
        factory: CrowdloanOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        self.factory = factory
        self.connection = connection
        self.runtimeService = runtimeService
    }

    func fetchCrowdloansOperation() -> CompoundOperationWrapper<[Crowdloan]> {
        factory.fetchCrowdloansOperation(
            connection: connection,
            runtimeService: runtimeService
        )
    }

    func fetchContributionOperation(
        accountId: AccountId,
        index: FundIndex
    ) -> CompoundOperationWrapper<CrowdloanContributionResponse> {
        factory.fetchContributionOperation(
            connection: connection,
            runtimeService: runtimeService,
            accountId: accountId,
            index: index
        )
    }
}

final class CrowdloanOnChainSyncService: BaseSyncService {
    private let remoteOperationsFactory: CrowdloanContributionOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let operationQueue: OperationQueue
    private let accountId: AccountId
    private let chainId: ChainModel.Id
    private let repository: AnyDataProviderRepository<CrowdloanContributionData>

    init(
        remoteOperationsFactory: CrowdloanContributionOperationFactoryProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<CrowdloanContributionData>,
        accountId: AccountId,
        chainId: ChainModel.Id
    ) {
        self.remoteOperationsFactory = remoteOperationsFactory
        self.operationQueue = operationQueue
        self.repository = repository
        self.accountId = accountId
        self.chainId = chainId
        operationManager = OperationManager(operationQueue: operationQueue)
    }

    private func contributionsFetchOperation(
        dependingOn fetchCrowdloansOperation: CompoundOperationWrapper<[Crowdloan]>,
        accountId: AccountId
    ) -> BaseOperation<[RemoteCrowdloanContribution]> {
        let contributionsOperation: BaseOperation<[RemoteCrowdloanContribution]> =
            OperationCombiningService(operationManager: operationManager) { [weak self] in
                guard let self = self else {
                    return []
                }
                let crowdloans = try fetchCrowdloansOperation.targetOperation.extractNoCancellableResultData()

                let wrappers = crowdloans.map { crowdloan in
                    let fetchOperation = self.remoteOperationsFactory.fetchContributionOperation(
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
                        dependencies: [fetchOperation.targetOperation]
                    )
                }

                wrappers.forEach {
                    $0.addDependency(wrapper: crowdloans)
                }

            }.longrunOperation()

        contributionsOperation.addDependency(fetchCrowdloansOperation.targetOperation)

        return contributionsOperation
    }

    private func createChangesOperationWrapper(
        dependingOn contributionsOperation: BaseOperation<[RemoteCrowdloanContribution]>,
        chainId: ChainModel.Id,
        accountId: AccountId
    ) -> CompoundOperationWrapper<[DataProviderChange<CrowdloanContributionData>]?> {
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

        return CompoundOperationWrapper(
            targetOperation: changesOperation,
            dependencies: [contributionsOperation]
        )
    }

    private func createSaveOperation(
        dependingOn operation: CompoundOperationWrapper<[DataProviderChange<CrowdloanContributionData>]?>
    ) -> BaseOperation<Void> {
        let replaceOperation = repository.replaceOperation {
            guard let changes = try operation.targetOperation.extractNoCancellableResultData() else {
                return []
            }
            return changes.compactMap(\.item)
        }

        replaceOperation.addDependency(operation.targetOperation)
        return replaceOperation
    }

    override func performSyncUp() {
        let fetchCrowdloansOperation = remoteOperationsFactory.fetchCrowdloansOperation()
        let contributionsFetchOperation = contributionsFetchOperation(
            dependingOn: fetchCrowdloansOperation,
            accountId: accountId
        )
        let changesWrapper = createChangesOperationWrapper(
            dependingOn: contributionsFetchOperation,
            chainId: chainId,
            accountId: accountId
        )
        let saveOperation = createSaveOperation(dependingOn: changesWrapper)

        changesWrapper.addDependency(operations: [contributionsFetchOperation])
        let operations = fetchCrowdloansOperation.allOperations + [contributionsFetchOperation]
            + changesWrapper.allOperations // + [saveOperation]

        operationManager.enqueue(operations: operations, in: .transient)
    }

    override func stopSyncUp() {
        operationQueue.cancelAllOperations()
    }
}

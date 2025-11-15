import Foundation
import SubstrateSdk
import Operation_iOS

final class CrowdloanOnChainSyncService: BaseSyncService {
    private let operationFactory: AhOpsOperationFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let accountId: AccountId
    private let chainId: ChainModel.Id
    private let repository: AnyDataProviderRepository<CrowdloanContributionData>
    private let operationQueue: OperationQueue

    init(
        operationFactory: AhOpsOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<CrowdloanContributionData>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.operationFactory = operationFactory
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.accountId = accountId
        self.operationQueue = operationQueue
        self.chainId = chainId

        super.init(logger: logger)
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
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            logger.error("Connection for chainId: \(chainId) is unavailable")
            completeImmediate(ChainRegistryError.connectionUnavailable)
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger.error("Runtime metadata for chainId: \(chainId) is unavailable")
            completeImmediate(ChainRegistryError.runtimeMetadaUnavailable)
            return
        }
    }

    override func stopSyncUp() {}
}

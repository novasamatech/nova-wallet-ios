import Foundation
import Operation_iOS

final class OfflineRuntimeCodingServiceProvider {
    let snapshotFactory: RuntimeSnapshotFactoryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue

    init(
        snapshotFactory: RuntimeSnapshotFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.snapshotFactory = snapshotFactory
        self.repository = repository
        self.operationQueue = operationQueue
    }
}

// MARK: - RuntimeCodingServiceProviderProtocol

extension OfflineRuntimeCodingServiceProvider: RuntimeCodingServiceProviderProtocol {
    func createRuntimeCodingServiceWrapper(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<RuntimeCodingServiceProtocol> {
        let chainFetchOperation = repository.fetchOperation(by: chainId, options: .init())

        let snapshotWrapper: CompoundOperationWrapper<RuntimeSnapshot?>
        snapshotWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            guard let chain = try chainFetchOperation.extractNoCancellableResultData() else {
                throw ChainProviderError.chainNotFound(chainId: chainId)
            }

            let runtimeProviderChain = RuntimeProviderChain(
                chainId: chain.chainId,
                typesUsage: chain.typesUsage,
                name: chain.name,
                isEthereumBased: chain.isEthereumBased
            )

            return self.snapshotFactory.createRuntimeSnapshotWrapper(for: runtimeProviderChain)
        }

        snapshotWrapper.addDependency(operations: [chainFetchOperation])

        let resultOperation = ClosureOperation<RuntimeCodingServiceProtocol> {
            guard let snapshot = try snapshotWrapper.targetOperation.extractNoCancellableResultData() else {
                throw RuntimeCodingServiceProviderError.runtimeMetadaUnavailable(chainId: chainId)
            }

            return OfflineRuntimeCodingService(snapshot: snapshot)
        }

        resultOperation.addDependency(snapshotWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [chainFetchOperation] + snapshotWrapper.allOperations
        )
    }
}

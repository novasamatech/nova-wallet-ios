import Foundation
import Operation_iOS

final class OfflineRuntimeCodingService {
    private let snapshotFactory: RuntimeSnapshotFactoryProtocol
    private let repository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue
    
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

// MARK: - RuntimeCodingServiceProtocol

extension OfflineRuntimeCodingService: RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        
    }
}

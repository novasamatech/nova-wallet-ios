import Foundation
import RobinHood

protocol PersistentExtrinsicServiceProtocol {
    func saveTransfer(
        chainAssetId: ChainAssetId,
        details: PersistTransferDetails,
        runningIn queue: DispatchQueue,
        completion closure: @escaping (Result<Void, Error>) -> Void
    )
}

final class PersistentExtrinsicService {
    let operationQueue: OperationQueue
    let factory: PersistExtrinsicFactoryProtocol

    init(
        repository: AnyDataProviderRepository<TransactionHistoryItem>,
        operationQueue: OperationQueue
    ) {
        factory = PersistExtrinsicFactory(repository: repository)
        self.operationQueue = operationQueue
    }
}

extension PersistentExtrinsicService: PersistentExtrinsicServiceProtocol {
    func saveTransfer(
        chainAssetId: ChainAssetId,
        details: PersistTransferDetails,
        runningIn queue: DispatchQueue,
        completion closure: @escaping (Result<Void, Error>) -> Void
    ) {
        let wrapper = factory.createTransferSaveOperation(
            chainAssetId: chainAssetId,
            details: details
        )

        wrapper.targetOperation.completionBlock = {
            queue.async {
                do {
                    try wrapper.targetOperation.extractNoCancellableResultData()
                    closure(.success(()))
                } catch {
                    closure(.failure(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
    }
}

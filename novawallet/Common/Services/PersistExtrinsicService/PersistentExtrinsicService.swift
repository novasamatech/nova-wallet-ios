import Foundation
import RobinHood

protocol PersistentExtrinsicServiceProtocol {
    func saveTransfer(
        source: TransactionHistoryItemSource,
        chainAssetId: ChainAssetId,
        details: PersistTransferDetails,
        runningIn queue: DispatchQueue,
        completion closure: @escaping (Result<Void, Error>) -> Void
    )

    func saveExtrinsic(
        source: TransactionHistoryItemSource,
        chainAssetId: ChainAssetId,
        details: PersistExtrinsicDetails,
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
        source: TransactionHistoryItemSource,
        chainAssetId: ChainAssetId,
        details: PersistTransferDetails,
        runningIn queue: DispatchQueue,
        completion closure: @escaping (Result<Void, Error>) -> Void
    ) {
        let wrapper = factory.createTransferSaveOperation(
            source: source,
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

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func saveExtrinsic(
        source: TransactionHistoryItemSource,
        chainAssetId: ChainAssetId,
        details: PersistExtrinsicDetails,
        runningIn queue: DispatchQueue,
        completion closure: @escaping (Result<Void, Error>) -> Void
    ) {
        let wrapper = factory.createExtrinsicSaveOperation(
            source: source,
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

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

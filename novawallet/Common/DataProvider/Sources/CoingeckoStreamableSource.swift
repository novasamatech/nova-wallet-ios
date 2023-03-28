import Foundation
import RobinHood

final class CoingeckoStreamableSource: StreamableSourceProtocol {
    typealias Model = PriceData

    let priceIds: [AssetModel.PriceId]
    let currency: Currency
    let repository: AnyDataProviderRepository<PriceData>
    let operationQueue: OperationQueue

    init(
        priceIds: [AssetModel.PriceId],
        currency: Currency,
        repository: AnyDataProviderRepository<PriceData>,
        operationQueue: OperationQueue
    ) {
        self.priceIds = priceIds
        self.currency = currency
        self.repository = repository
        self.operationQueue = operationQueue
    }

    func fetchHistory(runningIn queue: DispatchQueue?, commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {
        guard let closure = commitNotificationBlock else {
            return
        }

        let result: Result<Int, Error> = Result.success(0)

        if let queue = queue {
            queue.async {
                closure(result)
            }
        } else {
            closure(result)
        }
    }

    func refresh(runningIn queue: DispatchQueue?, commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {
        let fetchOperation = CoingeckoOperationFactory().fetchPriceOperation(
            for: priceIds,
            currency: currency
        )

        let saveOperation = repository.replaceOperation {
            try fetchOperation.extractNoCancellableResultData()
        }

        saveOperation.addDependency(fetchOperation)

        saveOperation.completionBlock = {
            do {
                let prices = try fetchOperation.extractNoCancellableResultData()
                dispatchInQueueWhenPossible(queue) {
                    commitNotificationBlock?(.success(prices.count))
                }
            } catch {
                dispatchInQueueWhenPossible(queue) {
                    commitNotificationBlock?(.failure(error))
                }
            }
        }

        operationQueue.addOperations([fetchOperation, saveOperation], waitUntilFinished: false)
    }
}

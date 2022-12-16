import Foundation
import RobinHood
import SubstrateSdk

final class ReferendumMetadataDetailsProviderSource {
    typealias Model = ReferendumMetadataLocal

    let chainId: ChainModel.Id
    let referendumId: ReferendumIdLocal
    let apiParameters: JSON?
    let operationFactory: PolkassemblyOperationFactoryProtocol
    let repository: AnyDataProviderRepository<ReferendumMetadataLocal>
    let operationQueue: OperationQueue

    init(
        chainId: ChainModel.Id,
        referendumId: ReferendumIdLocal,
        apiParameters: JSON?,
        operationFactory: PolkassemblyOperationFactoryProtocol,
        repository: AnyDataProviderRepository<ReferendumMetadataLocal>,
        operationQueue: OperationQueue
    ) {
        self.chainId = chainId
        self.referendumId = referendumId
        self.apiParameters = apiParameters
        self.operationFactory = operationFactory
        self.repository = repository
        self.operationQueue = operationQueue
    }
}

extension ReferendumMetadataDetailsProviderSource: StreamableSourceProtocol {
    func fetchHistory(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
    ) {
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

    func refresh(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
    ) {
        let remoteFetchOperation = operationFactory.createDetailsOperation(
            for: referendumId,
            parameters: apiParameters
        )

        let identifier = ReferendumMetadataLocal.identifier(from: chainId, referendumId: referendumId)
        let saveOperation = repository.saveOperation({
            let optItem = try remoteFetchOperation.extractNoCancellableResultData()
            if let item = optItem {
                return [item]
            } else {
                return []
            }
        }, {
            let optItem = try remoteFetchOperation.extractNoCancellableResultData()

            if optItem == nil {
                return [identifier]
            } else {
                return []
            }
        })

        saveOperation.addDependency(remoteFetchOperation)

        saveOperation.completionBlock = {
            do {
                try saveOperation.extractNoCancellableResultData()

                let item = try remoteFetchOperation.extractNoCancellableResultData()
                let count = item != nil ? 1 : 0

                dispatchInQueueWhenPossible(queue) {
                    commitNotificationBlock?(.success(count))
                }
            } catch {
                dispatchInQueueWhenPossible(queue) {
                    commitNotificationBlock?(.failure(error))
                }
            }
        }

        let operations = [remoteFetchOperation, saveOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }
}

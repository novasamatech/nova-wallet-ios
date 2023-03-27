import Foundation
import RobinHood
import SubstrateSdk

final class ReferendumsMetadataPreviewProviderSource {
    typealias Model = ReferendumMetadataLocal

    let operationFactory: GovMetadataOperationFactoryProtocol
    let repository: AnyDataProviderRepository<ReferendumMetadataLocal>
    let operationQueue: OperationQueue
    let apiParameters: JSON?

    init(
        operationFactory: GovMetadataOperationFactoryProtocol,
        apiParameters: JSON?,
        repository: AnyDataProviderRepository<ReferendumMetadataLocal>,
        operationQueue: OperationQueue
    ) {
        self.operationFactory = operationFactory
        self.apiParameters = apiParameters
        self.repository = repository
        self.operationQueue = operationQueue
    }
}

extension ReferendumsMetadataPreviewProviderSource: StreamableSourceProtocol {
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
        let remoteFetchOperation = operationFactory.createPreviewsOperation(for: apiParameters)
        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let changesOperation = ClosureOperation<[ReferendumMetadataLocal]> {
            let localItems = try localFetchOperation.extractNoCancellableResultData().reduceToDict()
            let remoteItems = try remoteFetchOperation.extractNoCancellableResultData()

            return remoteItems.map { remoteItem in
                let localItem = localItems[remoteItem.identifier]

                return ReferendumMetadataLocal(
                    chainId: remoteItem.chainId,
                    referendumId: remoteItem.referendumId,
                    title: remoteItem.title,
                    content: localItem?.content,
                    proposer: localItem?.proposer,
                    timeline: localItem?.timeline
                )
            }
        }

        localFetchOperation.addDependency(remoteFetchOperation)

        changesOperation.addDependency(remoteFetchOperation)
        changesOperation.addDependency(localFetchOperation)

        let saveOperation = repository.replaceOperation {
            try changesOperation.extractNoCancellableResultData()
        }

        saveOperation.addDependency(changesOperation)

        saveOperation.completionBlock = {
            do {
                try saveOperation.extractNoCancellableResultData()

                let count = try changesOperation.extractNoCancellableResultData().count

                dispatchInQueueWhenPossible(queue) {
                    commitNotificationBlock?(.success(count))
                }
            } catch {
                dispatchInQueueWhenPossible(queue) {
                    commitNotificationBlock?(.failure(error))
                }
            }
        }

        let operations = [remoteFetchOperation, localFetchOperation, changesOperation, saveOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }
}

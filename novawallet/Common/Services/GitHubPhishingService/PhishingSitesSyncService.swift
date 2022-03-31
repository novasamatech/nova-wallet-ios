import Foundation
import RobinHood

class PhishingSitesSyncService: BaseSyncService {
    private var syncWrapper: CancellableCall?
    private let operationFactory: GitHubOperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let url: URL
    private let repository: AnyDataProviderRepository<PhishingSite>

    init(
        url: URL,
        operationFactory: GitHubOperationFactoryProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<PhishingSite>
    ) {
        self.url = url
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.repository = repository

        super.init()
    }

    override func performSyncUp() {
        let networkOperation = operationFactory.fetchPhishingSitesOperation(url)

        let mapOperation = ClosureOperation<[PhishingSite]> {
            let phishingSites = try networkOperation.extractNoCancellableResultData()

            return phishingSites.deny.map { PhishingSite(host: $0) }
        }

        mapOperation.addDependency(networkOperation)

        let replaceOperation = repository.replaceOperation {
            try mapOperation.extractNoCancellableResultData()
        }

        replaceOperation.addDependency(mapOperation)

        replaceOperation.completionBlock = { [weak self] in
            guard !replaceOperation.isCancelled else {
                return
            }

            do {
                try replaceOperation.extractNoCancellableResultData()

                self?.clearAndComplete(nil)
            } catch {
                self?.clearAndComplete(error)
            }
        }

        let wrapper = CompoundOperationWrapper(
            targetOperation: replaceOperation,
            dependencies: [networkOperation, mapOperation]
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    override func stopSyncUp() {
        syncWrapper?.cancel()
        syncWrapper = nil
    }

    private func clearAndComplete(_ error: Error?) {
        mutex.lock()

        syncWrapper = nil

        mutex.unlock()

        complete(error)
    }
}

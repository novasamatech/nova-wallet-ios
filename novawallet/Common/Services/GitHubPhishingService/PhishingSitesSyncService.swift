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

            return phishingSites.blocked().map { PhishingSite(host: $0) }
        }

        mapOperation.addDependency(networkOperation)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let diffOperation = ClosureOperation<DataChangesDiffCalculator<PhishingSite>.Changes> {
            let remoteItems = try mapOperation.extractNoCancellableResultData()
            let localItems = try fetchOperation.extractNoCancellableResultData()

            let calculator = DataChangesDiffCalculator<PhishingSite>()
            return calculator.diff(newItems: remoteItems, oldItems: localItems)
        }

        diffOperation.addDependency(fetchOperation)
        diffOperation.addDependency(mapOperation)

        let saveOperation = repository.saveOperation({
            try diffOperation.extractNoCancellableResultData().newOrUpdatedItems
        }, {
            try diffOperation.extractNoCancellableResultData().removedItems.map { $0.identifier }
        })

        saveOperation.addDependency(diffOperation)

        saveOperation.completionBlock = { [weak self] in
            guard !saveOperation.isCancelled else {
                return
            }

            do {
                try saveOperation.extractNoCancellableResultData()

                self?.clearAndComplete(nil)
            } catch {
                self?.clearAndComplete(error)
            }
        }

        let wrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [diffOperation, fetchOperation, mapOperation, networkOperation]
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

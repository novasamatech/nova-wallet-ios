import XCTest
@testable import novawallet
import RobinHood

class PhishingSitesSyncIntegrationTests: XCTestCase {

    func testSyncUp() {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let operationQueue = OperationQueue()
        let operationFactory = GitHubOperationFactory()
        let repository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createPhishingSitesRepository()

        let service = PhishingSitesSyncService(
            url: ApplicationConfig.shared.phishingDAppsURL,
            operationFactory: operationFactory,
            operationQueue: operationQueue,
            repository: repository
        )

        let mapper = PhishingSiteMapper()
        let observer = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { _ in
                true
            },
            processingQueue: nil
        )

        // when

        XCTAssertTrue(!service.isActive)
        XCTAssertTrue(!service.isSyncing)
        XCTAssertTrue(service.retryAttempt == 0)

        var items: [PhishingSite]?

        let syncExpectation = XCTestExpectation()

        observer.addObserver(self, deliverOn: .global()) { changes in
            let newItems = changes.compactMap { $0.item }

            if !newItems.isEmpty {
                items = newItems
                syncExpectation.fulfill()
            }
        }

        observer.start { error in
            if error != nil {
                syncExpectation.fulfill()
            }
        }

        service.setup()

        XCTAssertTrue(service.isActive)
        XCTAssertTrue(service.isSyncing)
        XCTAssertTrue(service.retryAttempt == 0)

        wait(for: [syncExpectation], timeout: 10)

        // then

        guard let syncedItems = items else {
            XCTFail("No items received")
            return
        }

        XCTAssertTrue(service.isActive)

        Logger.shared.info("Synced sites: \(syncedItems.count)")

        observer.removeObserver(self)
    }
}

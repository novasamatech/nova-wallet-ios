import CoreData
@testable import novawallet
import Operation_iOS
import XCTest

/// Pins which change batches observers receive from the Operation-iOS providers the local subscriptions are
/// built on: `StreamableProvider` over `CoreDataContextObservable` and `DataProvider` over a remote source.
/// Behaviour recorded on Operation-iOS 2.1.2.
final class DataProviderObserverCharacterizationTests: XCTestCase {
    private let operationQueue = OperationQueue()
    private let key = "storage-key"

    private var facade: SubstrateStorageTestFacade!
    private var repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem>!

    override func setUp() {
        super.setUp()

        facade = SubstrateStorageTestFacade()
        repository = facade.createRepository()
    }

    // MARK: StreamableProvider

    func testStreamableProviderReportsInitialStateThenStoreChanges() throws {
        try save([makeItem(key, 1), makeItem("other-key", 5)])
        let provider = makeStorageProvider()
        let recorder = ChangeRecorder()

        let initial = recorder.expectBatches(1)
        provider.addObserver(
            self,
            deliverOn: .global(),
            executing: recorder.record,
            failing: { XCTFail("Unexpected failure: \($0)") },
            options: StreamableProviderObserverOptions(refreshWhenEmpty: false)
        )
        wait(for: [initial], timeout: 10)

        let updated = recorder.expectBatches(2)
        try save([makeItem(key, 2)])
        wait(for: [updated], timeout: 10)

        let deleted = recorder.expectBatches(3)
        try run(repository.saveOperation({ [] }, { [self.key] }))
        wait(for: [deleted], timeout: 10)

        let inserted = recorder.expectBatches(4)
        try save([makeItem(key, 3)])
        wait(for: [inserted], timeout: 10)

        XCTAssertEqual(
            recorder.batches,
            [["insert storage-key=1"], ["update storage-key=2"], ["delete storage-key"], ["insert storage-key=3"]]
        )

        provider.removeObserver(self)
    }

    func testStreamableProviderReportsEmptyInitialState() throws {
        let provider = makeStorageProvider()
        let recorder = ChangeRecorder()

        let initial = recorder.expectCallbacks(1)
        provider.addObserver(
            self,
            deliverOn: .global(),
            executing: recorder.record,
            failing: { XCTFail("Unexpected failure: \($0)") },
            options: StreamableProviderObserverOptions(refreshWhenEmpty: false)
        )
        wait(for: [initial], timeout: 10)

        let inserted = recorder.expectBatches(1)
        try save([makeItem(key, 1)])
        wait(for: [inserted], timeout: 10)

        XCTAssertEqual(recorder.batches, [["insert storage-key=1"]])

        provider.removeObserver(self)
    }

    func testStreamableProviderFetchReadsRepository() throws {
        try save([makeItem(key, 1), makeItem("other-key", 5)])
        let provider = makeStorageProvider()
        let fetched = expectation(description: "fetch completed")
        var result: Result<[ChainStorageItem], Error>?

        _ = provider.fetch(offset: 0, count: 10, synchronized: false) { fetchResult in
            result = fetchResult
            fetched.fulfill()
        }
        wait(for: [fetched], timeout: 10)

        XCTAssertEqual(try result?.get(), [makeItem(key, 1)])
    }

    // MARK: DataProvider

    func testDataProviderSynchronizesSourceIntoRepositoryAndNotifiesDifference() throws {
        let source = RemoteSourceStub(items: [makeItem("a", 1), makeItem("b", 2)])
        let provider = DataProvider(
            source: AnyDataProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: DataProviderEventTrigger.onAddObserver
        )
        let recorder = ChangeRecorder()

        let synchronized = recorder.expectBatches(1)
        provider.addObserver(
            self,
            deliverOn: .global(),
            executing: recorder.record,
            failing: { XCTFail("Unexpected failure: \($0)") },
            options: DataProviderObserverOptions(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)
        )
        wait(for: [synchronized], timeout: 10)

        source.items = [makeItem("a", 9), makeItem("c", 3)]
        let refreshed = recorder.expectBatches(2)
        provider.refresh()
        wait(for: [refreshed], timeout: 10)

        XCTAssertEqual(
            recorder.batches,
            [["insert a=1", "insert b=2"], ["delete b", "insert c=3", "update a=9"]]
        )
        XCTAssertEqual(
            try run(repository.fetchAllOperation(with: RepositoryFetchOptions())).sorted { $0.identifier < $1.identifier },
            [makeItem("a", 9), makeItem("c", 3)]
        )

        provider.removeObserver(self)
    }

    func testDataProviderReportsSourceFailureOnlyWhenAlwaysNotifying() throws {
        let source = RemoteSourceStub(items: [], error: CommonError.noDataRetrieved)
        let provider = DataProvider(
            source: AnyDataProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: DataProviderEventTrigger.onAddObserver
        )
        let failed = expectation(description: "failure reported")
        var receivedError: Error?

        provider.addObserver(
            self,
            deliverOn: .global(),
            executing: { _ in },
            failing: { error in
                receivedError = error
                failed.fulfill()
            },
            options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true, waitsInProgressSyncOnAdd: false)
        )
        wait(for: [failed], timeout: 10)

        XCTAssertEqual(receivedError as? CommonError, .noDataRetrieved)

        provider.removeObserver(self)
    }
}

private extension DataProviderObserverCharacterizationTests {
    func makeItem(_ identifier: String, _ byte: UInt8) -> ChainStorageItem {
        ChainStorageItem(identifier: identifier, data: Data([byte]))
    }

    /// The production construction: `CoreDataContextObservable` filtered by key over the shared store.
    func makeStorageProvider() -> StreamableProvider<ChainStorageItem> {
        SubstrateDataProviderFactory(
            facade: facade,
            operationManager: OperationManager(operationQueue: operationQueue)
        )
        .createStorageProvider(for: key)
    }

    @discardableResult
    func run<T>(_ operation: BaseOperation<T>) throws -> T {
        operationQueue.addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    func save(_ items: [ChainStorageItem]) throws {
        try run(repository.saveOperation({ items }, { [] }))
    }
}

/// Collects observer callbacks; a batch is the sorted description of one non-empty callback.
private final class ChangeRecorder {
    private let lock = NSLock()
    private var storedBatches: [[String]] = []
    private var callbacksCount = 0
    private var pending: [(expectation: XCTestExpectation, isSatisfied: (ChangeRecorder) -> Bool)] = []

    var batches: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return storedBatches
    }

    func record(_ changes: [DataProviderChange<ChainStorageItem>]) {
        lock.lock()

        callbacksCount += 1

        if !changes.isEmpty {
            storedBatches.append(changes.map(Self.describe).sorted())
        }

        fulfillSatisfied()

        lock.unlock()
    }

    func expectBatches(_ count: Int) -> XCTestExpectation {
        expect(description: "\(count) change batches") { $0.storedBatches.count >= count }
    }

    func expectCallbacks(_ count: Int) -> XCTestExpectation {
        expect(description: "\(count) callbacks") { $0.callbacksCount >= count }
    }

    private func expect(
        description: String,
        isSatisfied: @escaping (ChangeRecorder) -> Bool
    ) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: description)

        lock.lock()
        pending.append((expectation, isSatisfied))
        fulfillSatisfied()
        lock.unlock()

        return expectation
    }

    private func fulfillSatisfied() {
        pending.filter { $0.isSatisfied(self) }.forEach { $0.expectation.fulfill() }
        pending.removeAll { $0.isSatisfied(self) }
    }

    private static func describe(_ change: DataProviderChange<ChainStorageItem>) -> String {
        switch change {
        case let .insert(item):
            "insert \(item.identifier)=\(item.data.first ?? 0)"
        case let .update(item):
            "update \(item.identifier)=\(item.data.first ?? 0)"
        case let .delete(identifier):
            "delete \(identifier)"
        }
    }
}

private final class RemoteSourceStub: DataProviderSourceProtocol {
    typealias Model = ChainStorageItem

    private let lock = NSLock()
    private var storedItems: [ChainStorageItem]
    private let error: Error?

    var items: [ChainStorageItem] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedItems
        }
        set {
            lock.lock()
            storedItems = newValue
            lock.unlock()
        }
    }

    init(items: [ChainStorageItem], error: Error? = nil) {
        storedItems = items
        self.error = error
    }

    func fetchOperation(by modelId: String) -> CompoundOperationWrapper<ChainStorageItem?> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { self.items.first { $0.identifier == modelId } })
    }

    func fetchOperation(page _: UInt) -> CompoundOperationWrapper<[ChainStorageItem]> {
        CompoundOperationWrapper(
            targetOperation: ClosureOperation {
                if let error = self.error {
                    throw error
                }

                return self.items
            }
        )
    }
}

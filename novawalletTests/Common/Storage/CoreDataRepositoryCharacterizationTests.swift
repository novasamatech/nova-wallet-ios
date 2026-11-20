import CoreData
@testable import novawallet
import Operation_iOS
import XCTest

/// Pins the `CoreDataRepository` contract the app's storage layer is written against (save, fetch, delete,
/// replace, count, slices, filters, failures) on the in-memory Substrate store.
/// Behaviour recorded on Operation-iOS 2.1.2.
final class CoreDataRepositoryCharacterizationTests: XCTestCase {
    private typealias Repository = CoreDataRepository<ChainStorageItem, CDChainStorageItem>

    private let operationQueue = OperationQueue()

    private var facade: SubstrateStorageTestFacade!
    private var repository: Repository!

    override func setUp() {
        super.setUp()

        facade = SubstrateStorageTestFacade()
        repository = facade.createRepository(
            sortDescriptors: [NSSortDescriptor(key: #keyPath(CDChainStorageItem.identifier), ascending: true)]
        )
    }

    func testSaveThenFetchAllReturnsSortedModels() throws {
        try save([makeItem("b", 2), makeItem("a", 1), makeItem("c", 3)])

        XCTAssertEqual(try fetchAll(), [makeItem("a", 1), makeItem("b", 2), makeItem("c", 3)])
    }

    func testFetchByIdentifier() throws {
        try save([makeItem("a", 1), makeItem("b", 2)])

        XCTAssertEqual(try run(repository.fetchOperation(by: { "b" }, options: RepositoryFetchOptions())), makeItem("b", 2))
        XCTAssertNil(try run(repository.fetchOperation(by: { "missing" }, options: RepositoryFetchOptions())))
    }

    func testSaveUpdatesExistingModelByIdentifier() throws {
        try save([makeItem("a", 1)])
        try save([makeItem("a", 9)])

        XCTAssertEqual(try fetchAll(), [makeItem("a", 9)])
        XCTAssertEqual(try run(repository.fetchCountOperation()), 1)
    }

    func testSaveAppliesUpdatesAndDeletesInOneOperation() throws {
        try save([makeItem("a", 1), makeItem("b", 2)])

        try run(repository.saveOperation({ [self.makeItem("c", 3)] }, { ["a", "missing"] }))

        XCTAssertEqual(try fetchAll(), [makeItem("b", 2), makeItem("c", 3)])
    }

    func testReplaceDropsEverythingNotInNewSet() throws {
        try save([makeItem("a", 1), makeItem("b", 2)])

        try run(repository.replaceOperation { [self.makeItem("b", 7), self.makeItem("d", 4)] })

        XCTAssertEqual(try fetchAll(), [makeItem("b", 7), makeItem("d", 4)])
    }

    func testDeleteAllAndCount() throws {
        try save([makeItem("a", 1), makeItem("b", 2)])
        XCTAssertEqual(try run(repository.fetchCountOperation()), 2)

        try run(repository.deleteAllOperation())

        XCTAssertEqual(try run(repository.fetchCountOperation()), 0)
        XCTAssertEqual(try fetchAll(), [])
    }

    func testSliceRequests() throws {
        try save((1 ... 5).map { makeItem("\($0)", UInt8($0)) })

        let forward = try run(repository.fetchOperation(
            by: RepositorySliceRequest(offset: 1, count: 2, reversed: false),
            options: RepositoryFetchOptions()
        ))
        let reversed = try run(repository.fetchOperation(
            by: RepositorySliceRequest(offset: 1, count: 2, reversed: true),
            options: RepositoryFetchOptions()
        ))
        let overflowing = try run(repository.fetchOperation(
            by: RepositorySliceRequest(offset: 4, count: 10, reversed: false),
            options: RepositoryFetchOptions()
        ))

        XCTAssertEqual(forward.map(\.identifier), ["2", "3"])
        XCTAssertEqual(reversed.map(\.identifier), ["4", "3"])
        XCTAssertEqual(overflowing.map(\.identifier), ["5"])
    }

    func testFilteredRepositorySeesAndReplacesOnlyMatchingModels() throws {
        try save([makeItem("keep", 1), makeItem("scoped-1", 2), makeItem("scoped-2", 3)])
        let scoped: Repository = facade.createRepository(
            filter: NSPredicate(format: "%K BEGINSWITH %@", #keyPath(CDChainStorageItem.identifier), "scoped"),
            sortDescriptors: [NSSortDescriptor(key: #keyPath(CDChainStorageItem.identifier), ascending: true)]
        )

        XCTAssertEqual(try run(scoped.fetchAllOperation(with: RepositoryFetchOptions())).map(\.identifier), ["scoped-1", "scoped-2"])
        XCTAssertEqual(try run(scoped.fetchCountOperation()), 2)

        try run(scoped.deleteAllOperation())

        XCTAssertEqual(try fetchAll(), [makeItem("keep", 1)])
    }

    func testThrowingSaveClosureFailsOperationAndKeepsStore() throws {
        try save([makeItem("a", 1)])

        let operation = repository.saveOperation({ throw CommonError.dataCorruption }, { ["a"] })
        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertThrowsError(try operation.extractNoCancellableResultData()) { error in
            XCTAssertEqual(error as? CommonError, .dataCorruption)
        }
        XCTAssertEqual(try fetchAll(), [makeItem("a", 1)])
    }

    func testSaveCancelledBeforeStartIsFinishedAndLeavesStoreUntouched() throws {
        let operation = repository.saveOperation({ [self.makeItem("a", 1)] }, { [] })

        operation.cancel()

        // a cancelled operation is already finished: it can no longer be enqueued, dependants just see no result
        XCTAssertTrue(operation.isFinished)
        XCTAssertNil(operation.result)
        XCTAssertEqual(try fetchAll(), [])
    }

    func testConcurrentSavesAllLand() throws {
        let operations = (0 ..< 40).map { index in
            repository.saveOperation({ [self.makeItem("item-\(index)", UInt8(index))] }, { [] })
        }

        operationQueue.addOperations(operations, waitUntilFinished: true)

        try operations.forEach { try $0.extractNoCancellableResultData() }
        XCTAssertEqual(try run(repository.fetchCountOperation()), 40)
    }

    func testSeparateRepositoriesShareTheStore() throws {
        try save([makeItem("a", 1)])
        let other: Repository = facade.createRepository()

        XCTAssertEqual(try run(other.fetchAllOperation(with: RepositoryFetchOptions())), [makeItem("a", 1)])
    }

    func testSeparateFacadesAreIsolated() throws {
        try save([makeItem("a", 1)])
        let other: Repository = SubstrateStorageTestFacade().createRepository()

        XCTAssertEqual(try run(other.fetchAllOperation(with: RepositoryFetchOptions())), [])
    }
}

private extension CoreDataRepositoryCharacterizationTests {
    func makeItem(_ identifier: String, _ byte: UInt8) -> ChainStorageItem {
        ChainStorageItem(identifier: identifier, data: Data(repeating: byte, count: 4))
    }

    @discardableResult
    func run<T>(_ operation: BaseOperation<T>) throws -> T {
        operationQueue.addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    func save(_ items: [ChainStorageItem]) throws {
        try run(repository.saveOperation({ items }, { [] }))
    }

    func fetchAll() throws -> [ChainStorageItem] {
        try run(repository.fetchAllOperation(with: RepositoryFetchOptions()))
    }
}

import XCTest
@testable import novawallet
import Operation_iOS

final class AnalyticsEventQueueTests: XCTestCase {
    private func makeQueue(maxCount: Int = 500) -> CoreDataAnalyticsEventQueue {
        let facade = UserDataStorageTestFacade()
        let repository: CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent> =
            facade.createRepository(
                filter: nil,
                sortDescriptors: [.analyticsEventsBySequence],
                mapper: AnyCoreDataMapper(AnalyticsPendingEventMapper())
            )

        return CoreDataAnalyticsEventQueue(
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            maxCount: maxCount
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func run<T>(_ operation: BaseOperation<T>) throws -> T {
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData()
    }

    private func enqueue(_ queue: CoreDataAnalyticsEventQueue, _ names: [String]) throws {
        for name in names {
            try run(queue.enqueueWrapper(
                name: name,
                timestamp: Date(timeIntervalSince1970: 1),
                payload: Data("{}".utf8)
            ))
        }
    }

    func testPeekReturnsOldestFirstRegardlessOfTimestamp() throws {
        let queue = makeQueue()

        // Timestamps deliberately run backwards: FIFO must follow insertion order,
        // not the clock, so that a device clock correction cannot reorder the queue.
        try run(queue.enqueueWrapper(
            name: "first",
            timestamp: Date(timeIntervalSince1970: 900),
            payload: Data("{}".utf8)
        ))
        try run(queue.enqueueWrapper(
            name: "second",
            timestamp: Date(timeIntervalSince1970: 100),
            payload: Data("{}".utf8)
        ))
        try run(queue.enqueueWrapper(
            name: "third",
            timestamp: Date(timeIntervalSince1970: 500),
            payload: Data("{}".utf8)
        ))

        let peeked = try run(queue.peekWrapper(count: 10))
        XCTAssertEqual(peeked.map(\.name), ["first", "second", "third"])
    }

    func testPeekIsLimitedToTheRequestedCount() throws {
        let queue = makeQueue()
        try enqueue(queue, (0 ..< 10).map { "event_\($0)" })

        let peeked = try run(queue.peekWrapper(count: 4))
        XCTAssertEqual(peeked.map(\.name), ["event_0", "event_1", "event_2", "event_3"])
    }

    func testTrimKeepsTheNewestMaxCount() throws {
        let queue = makeQueue(maxCount: 5)
        try enqueue(queue, (0 ..< 8).map { "event_\($0)" })

        XCTAssertEqual(try run(queue.countOperation()), 5)

        let peeked = try run(queue.peekWrapper(count: 10))
        XCTAssertEqual(peeked.map(\.name), ["event_3", "event_4", "event_5", "event_6", "event_7"])
    }

    func testDropRemovesExactlyTheGivenIds() throws {
        let queue = makeQueue()
        try enqueue(queue, ["a", "b", "c"])

        let batch = try run(queue.peekWrapper(count: 2))
        _ = try run(queue.dropOperation(ids: batch.map(\.identifier)))

        XCTAssertEqual(try run(queue.countOperation()), 1)
        XCTAssertEqual(try run(queue.peekWrapper(count: 10)).map(\.name), ["c"])
    }

    func testClearEmptiesTheQueue() throws {
        let queue = makeQueue()
        try enqueue(queue, ["a", "b", "c"])

        _ = try run(queue.clearOperation())

        XCTAssertEqual(try run(queue.countOperation()), 0)
    }

    func testSequenceContinuesAfterAPartialDrain() throws {
        let queue = makeQueue()
        try enqueue(queue, ["a", "b"])

        let batch = try run(queue.peekWrapper(count: 1))
        _ = try run(queue.dropOperation(ids: batch.map(\.identifier)))

        try enqueue(queue, ["c"])

        // "b" was enqueued before "c" and must still come first.
        XCTAssertEqual(try run(queue.peekWrapper(count: 10)).map(\.name), ["b", "c"])
    }

    func testSequenceRestartsAfterAClear() throws {
        let queue = makeQueue()
        try enqueue(queue, ["a", "b", "c"])
        _ = try run(queue.clearOperation())
        try enqueue(queue, ["d", "e"])

        XCTAssertEqual(try run(queue.peekWrapper(count: 10)).map(\.name), ["d", "e"])
        XCTAssertEqual(try run(queue.countOperation()), 2)
    }

    func testPoisonRowIsReportedAndCanBeDropped() throws {
        // A row whose payload the mapper cannot read must be reachable by id so the
        // uploader can delete it, rather than wedging the queue forever.
        let facade = UserDataStorageTestFacade()
        let goodRepository: CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent> =
            facade.createRepository(
                filter: nil,
                sortDescriptors: [.analyticsEventsBySequence],
                mapper: AnyCoreDataMapper(AnalyticsPendingEventMapper())
            )

        let queue = CoreDataAnalyticsEventQueue(
            repository: AnyDataProviderRepository(goodRepository),
            operationQueue: OperationQueue(),
            maxCount: 500
        )

        try enqueue(queue, ["a"])
        let identifier = try run(queue.peekWrapper(count: 1))[0].identifier

        _ = try run(queue.dropOperation(ids: [identifier]))
        XCTAssertEqual(try run(queue.countOperation()), 0)
    }
}

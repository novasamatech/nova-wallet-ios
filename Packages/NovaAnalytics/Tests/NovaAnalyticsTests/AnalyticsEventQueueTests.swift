import XCTest
@testable import NovaAnalytics
import Operation_iOS

final class AnalyticsEventQueueTests: XCTestCase {
    private func makeQueue(maxCount: Int = 500) -> CoreDataAnalyticsEventQueue {
        CoreDataAnalyticsEventQueue(
            repository: AnyDataProviderRepository(AnalyticsStorageTestFacade().createEventRepository()),
            maxCount: maxCount
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func run<T>(_ operation: BaseOperation<T>) throws -> T {
        try run(CompoundOperationWrapper(targetOperation: operation))
    }

    private func enqueue(
        _ queue: CoreDataAnalyticsEventQueue,
        _ name: String,
        at timestamp: TimeInterval = 1,
        consentEpoch: Int = 0
    ) throws {
        try run(queue.enqueueWrapper(
            name: name,
            timestamp: Date(timeIntervalSince1970: timestamp),
            payload: Data("{}".utf8),
            consentEpoch: consentEpoch
        ))
    }

    func testPeekReturnsOldestFirstRegardlessOfTimestamp() throws {
        let queue = makeQueue()
        try enqueue(queue, "first", at: 900)
        try enqueue(queue, "second", at: 100)
        try enqueue(queue, "third", at: 500)

        XCTAssertEqual(try run(queue.peekWrapper(count: 10)).map(\.name), ["first", "second", "third"])
    }

    func testTrimKeepsTheNewestMaxCount() throws {
        let queue = makeQueue(maxCount: 5)

        for index in 0 ..< 8 {
            try enqueue(queue, "event_\(index)")
        }

        XCTAssertEqual(try run(queue.countOperation()), 5)
        XCTAssertEqual(
            try run(queue.peekWrapper(count: 10)).map(\.name),
            ["event_3", "event_4", "event_5", "event_6", "event_7"]
        )
    }

    func testDropRemovesExactlyTheGivenIds() throws {
        let queue = makeQueue()

        for name in ["a", "b", "c"] {
            try enqueue(queue, name)
        }

        let batch = try run(queue.peekWrapper(count: 2))
        _ = try run(queue.dropOperation(ids: batch.map(\.identifier)))

        XCTAssertEqual(try run(queue.countOperation()), 1)
        XCTAssertEqual(try run(queue.peekWrapper(count: 10)).map(\.name), ["c"])
    }

    func testEnqueueStampsTheRowWithTheGivenConsentEpoch() throws {
        let queue = makeQueue()
        try enqueue(queue, "a", consentEpoch: 7)

        XCTAssertEqual(try run(queue.peekWrapper(count: 1)).map(\.consentEpoch), [7])
    }
}

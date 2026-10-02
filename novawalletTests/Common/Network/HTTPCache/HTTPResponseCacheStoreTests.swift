@testable import novawallet
import Operation_iOS
import XCTest

private final class ManualClock {
    private let lock = NSLock()
    private var value: TimeInterval = 1000

    var now: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        value += interval
        lock.unlock()
    }
}

private final class CountingFetch {
    private let directives: HTTPCacheDirectives

    private(set) var count = 0

    init(directives: HTTPCacheDirectives) {
        self.directives = directives
    }

    func makeWrapper() -> CompoundOperationWrapper<HTTPCacheFetchOutcome<String>> {
        count += 1

        return .createWithResult(.response("response \(count)", directives))
    }
}

final class HTTPResponseCacheStoreTests: XCTestCase {
    private let key = "subnets"

    func testReusableResponseIsServedWithoutAFetchUntilItsLifetimeEnds() throws {
        let clock = ManualClock()
        let fetch = CountingFetch(directives: .reusable(lifetime: 60))
        let store = makeStore(clock: clock)

        let fetched = try deliver(from: store, fetch: fetch)
        clock.advance(by: 59)
        let served = try deliver(from: store, fetch: fetch)
        clock.advance(by: 1)
        let peekAtLifetimeEnd = store.peek(key)
        let refetched = try deliver(from: store, fetch: fetch)

        XCTAssertEqual(fetched.value, "response 1")
        XCTAssertEqual(served.value, "response 1")
        XCTAssertFalse(served.isExpired)
        XCTAssertEqual(peekAtLifetimeEnd.value, "response 1")
        XCTAssertFalse(peekAtLifetimeEnd.isFresh)
        XCTAssertEqual(refetched.value, "response 2")
        XCTAssertFalse(refetched.isExpired)
        XCTAssertEqual(fetch.count, 2)
    }

    func testNotStorableResponseReachesItsCallerWithoutBeingStored() throws {
        let fetch = CountingFetch(directives: .notStorable)
        let store = makeStore(clock: ManualClock())

        let first = try deliver(from: store, fetch: fetch)
        let peekAfterResponse = store.peek(key)
        let second = try deliver(from: store, fetch: fetch)

        XCTAssertEqual(first.value, "response 1")
        XCTAssertFalse(first.isExpired)
        XCTAssertNil(peekAfterResponse.value)
        XCTAssertEqual(second.value, "response 2")
        XCTAssertEqual(fetch.count, 2)
    }

    func testConcurrentRequestsShareOneFetchThatARemovedWaiterDoesNotCancel() throws {
        let store = makeStore(clock: ManualClock())
        let fetchStarted = expectation(description: "shared fetch started")
        let delivered = expectation(description: "remaining waiters delivered")
        delivered.expectedFulfillmentCount = 2

        var fetchCount = 0
        var heldReply: ((Result<HTTPCacheFetchOutcome<String>, Error>) -> Void)?
        var removedWaiterDeliveries = 0
        var remainingDeliveries: [Result<String, Error>] = []

        let fetch = { () -> CompoundOperationWrapper<HTTPCacheFetchOutcome<String>> in
            fetchCount += 1

            let operation = AsyncClosureOperation<HTTPCacheFetchOutcome<String>> { reply in
                heldReply = reply
                fetchStarted.fulfill()
            }

            return CompoundOperationWrapper(targetOperation: operation)
        }

        let removedWaiterId = UUID()

        store.request(key, waiterId: removedWaiterId, fetch: fetch) { _ in
            removedWaiterDeliveries += 1
        }

        for _ in 0 ..< 2 {
            store.request(key, waiterId: UUID(), fetch: fetch) { result in
                remainingDeliveries.append(result.map(\.value))
                delivered.fulfill()
            }
        }

        store.removeWaiter(removedWaiterId, for: key)
        wait(for: [fetchStarted], timeout: 10)
        try XCTUnwrap(heldReply)(.success(.response("shared", .reusable(lifetime: 60))))
        wait(for: [delivered], timeout: 10)

        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(try remainingDeliveries.map { try $0.get() }, ["shared", "shared"])
        XCTAssertEqual(removedWaiterDeliveries, 0)
    }

    private func makeStore(clock: ManualClock) -> HTTPResponseCacheStore<String, String> {
        HTTPResponseCacheStore(operationQueue: OperationQueue(), timeProvider: { clock.now })
    }

    private func deliver(
        from store: HTTPResponseCacheStore<String, String>,
        fetch: CountingFetch
    ) throws -> HTTPCacheDelivery<String> {
        let delivered = expectation(description: "request delivered")
        var delivery: Result<HTTPCacheDelivery<String>, Error>?

        store.request(key, waiterId: UUID(), fetch: fetch.makeWrapper) { result in
            delivery = result
            delivered.fulfill()
        }

        wait(for: [delivered], timeout: 10)

        return try XCTUnwrap(delivery).get()
    }
}

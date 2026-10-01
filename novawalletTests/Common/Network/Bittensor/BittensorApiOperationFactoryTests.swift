import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS

private final class ReplyLatch {
    private let lock = NSLock()
    private var isReleased = false
    private var heldReplies: [() -> Void] = []

    func hold(_ reply: @escaping () -> Void) {
        lock.lock()

        guard !isReleased else {
            lock.unlock()
            reply()
            return
        }

        heldReplies.append(reply)
        lock.unlock()
    }

    func release() {
        lock.lock()
        isReleased = true
        let replies = heldReplies
        heldReplies = []
        lock.unlock()

        replies.forEach { $0() }
    }
}

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

final class BittensorApiOperationFactoryTests: XCTestCase {
    func testSubnetsDecodeFromTheFixture() throws {
        let result = try fetch(makeFactory().createSubnetsWrapper())

        XCTAssertEqual(result.value.items.count, 10)
        XCTAssertEqual(result.value.items.first { $0.netuid == 64 }?.taoPerAlpha, "0.054961234")
        XCTAssertEqual(result.requestId, "fixture-1")
        XCTAssertFalse(result.isFromExpiredCache)
    }

    func testValidatorsDecodeForTheRequestedNetuid() throws {
        let result = try fetch(makeFactory().createValidatorsWrapper(netuid: 64))

        XCTAssertEqual(result.value.items.count, 8)
        XCTAssertEqual(Set(result.value.items.map(\.netuid)), [64])
        XCTAssertEqual(result.value.meta.completeness, .complete)
    }

    func testRootYieldDecodesTheRequestedPage() throws {
        let result = try fetch(makeFactory().createRootYieldWrapper(page: 1))

        XCTAssertEqual(result.value.items.first?.reportedRate, "13.8421")
        XCTAssertEqual(result.value.pageInfo, BittensorApi.PageInfo(page: 1, pageSize: 100, total: 3, nextPage: nil))
    }

    func testAlphaYieldDecodesTheRequestedNetuidAndPage() throws {
        let result = try fetch(makeFactory().createAlphaYieldWrapper(netuid: 64, page: 1))

        XCTAssertEqual(result.value.items.count, 8)
        XCTAssertEqual(Set(result.value.items.map(\.metricKind)), ["ALPHA_VALIDATOR_APY"])
        XCTAssertEqual(result.value.pageInfo.pageSize, 100)
    }

    func testRecommendationsDecodeWithTheirGeneration() throws {
        let result = try fetch(makeFactory().createRecommendationsWrapper())

        XCTAssertEqual(result.value.meta.generation.id, "8ebc85abd0bbeb6f282302ac48909c3d")
        XCTAssertEqual(result.value.meta.generation.servedFrom, .redis)
        XCTAssertEqual(result.value.classes.balanced.map(\.validatorName), ["Delta Relay", "Cinder Node", "Fjord Validators"])
    }

    func testRankedSubnetsDecodeWithRootFirst() throws {
        let result = try fetch(makeFactory().createRankedSubnetsWrapper())

        XCTAssertEqual(Array(result.value.items.map(\.netuid).prefix(3)), [0, 64, 4])
        XCTAssertEqual(result.value.meta.policy.classification, .pair)
    }

    func testUnknownServedFromIsAContractViolationWithTheRequestId() throws {
        let body = try mutatedBody(
            BittensorApiFixtureDocuments.recommendations(),
            replacing: [(#""servedFrom":"REDIS""#, #""servedFrom":"DISK""#)]
        )

        let transport = makeTransport(replies: [makeResponse(body, requestId: "req-enum")])

        let error = fetchError(makeFactory(transport: transport).createRecommendationsWrapper())

        guard case let .contractViolation(detail, requestId) = error else {
            return XCTFail("Unexpected error: \(String(describing: error))")
        }

        XCTAssertEqual(requestId, "req-enum")
        XCTAssertTrue(detail.contains("servedFrom"))
    }

    func testReorderedClientChecksAreAContractViolation() throws {
        let body = try mutatedBody(
            BittensorApiFixtureDocuments.recommendations(),
            replacing: [(#"["uid","validator_permit","take","last_update"]"#, #"["uid","take","validator_permit","last_update"]"#)]
        )

        let transport = makeTransport(replies: [makeResponse(body, requestId: "req-order")])

        let error = fetchError(makeFactory(transport: transport).createRecommendationsWrapper())

        guard case let .contractViolation(detail, requestId) = error else {
            return XCTFail("Unexpected error: \(String(describing: error))")
        }

        XCTAssertEqual(requestId, "req-order")
        XCTAssertTrue(detail.contains("clientChecks"))
    }

    func testGrammarInvalidDecimalIsAContractViolationWithTheRequestId() throws {
        let body = try mutatedBody(
            BittensorApiFixtureDocuments.recommendations(),
            replacing: [(#""maxTake":"0.18""#, #""maxTake":".18""#)]
        )

        let transport = makeTransport(replies: [makeResponse(body, requestId: "req-decimal")])

        let error = fetchError(makeFactory(transport: transport).createRecommendationsWrapper())

        guard case let .contractViolation(detail, requestId) = error else {
            return XCTFail("Unexpected error: \(String(describing: error))")
        }

        XCTAssertEqual(requestId, "req-decimal")
        XCTAssertTrue(detail.contains("maxTake"))
    }

    func testFreshCacheIsServedWithoutTheTransportUntilItsTtlExpires() throws {
        let clock = ManualClock()
        let body = try makeBody(BittensorApiFixtureDocuments.subnets())

        let transport = makeTransport(replies: [
            makeResponse(body, requestId: "req-first"),
            makeResponse(body, requestId: "req-second")
        ])

        let factory = makeFactory(transport: transport, clock: clock)

        let first = try fetch(factory.createSubnetsWrapper())
        clock.advance(by: 149)
        let cached = try fetch(factory.createSubnetsWrapper())
        clock.advance(by: 1)
        let refreshed = try fetch(factory.createSubnetsWrapper())

        XCTAssertEqual(cached.requestId, "req-first")
        XCTAssertEqual(cached.receivedAt, first.receivedAt)
        XCTAssertFalse(cached.isFromExpiredCache)
        XCTAssertEqual(refreshed.requestId, "req-second")
        verify(transport, times(2)).createResponseWrapper(for: any())
    }

    func testResponsesAreStampedOnTheCacheClock() throws {
        let clock = ManualClock()

        let result = try fetch(makeFactory(clock: clock).createRecommendationsWrapper())

        XCTAssertEqual(result.receivedAt, clock.now)
    }

    func testConcurrentCallersShareOneFetchThatACancelledCallerDoesNotCancel() throws {
        let replyLatch = ReplyLatch()
        let body = try makeBody(BittensorApiFixtureDocuments.subnets())

        let transport = makeTransport(
            replies: [makeResponse(body, requestId: "req-shared")],
            replyLatch: replyLatch
        )

        let factory = makeFactory(transport: transport)
        let queue = OperationQueue()

        let cancelled = factory.createSubnetsWrapper()
        let first = factory.createSubnetsWrapper()
        let second = factory.createSubnetsWrapper()
        let completed = completionExpectation(for: [cancelled, first, second])

        for wrapper in [cancelled, first, second] {
            queue.addOperation(wrapper.targetOperation)
            wrapper.dependencies.forEach { $0.start() }
        }

        verify(transport, times(1)).createResponseWrapper(for: any())

        cancelled.cancel()
        replyLatch.release()
        wait(for: [completed], timeout: 10)

        XCTAssertEqual(try first.targetOperation.extractNoCancellableResultData().requestId, "req-shared")
        XCTAssertEqual(try second.targetOperation.extractNoCancellableResultData().requestId, "req-shared")
        XCTAssertThrowsError(try cancelled.targetOperation.extractNoCancellableResultData()) { error in
            guard case .parentOperationCancelled = error as? BaseOperationError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        verify(transport, times(1)).createResponseWrapper(for: any())
    }

    func testAnOlderGenerationDoesNotReplaceTheNewerCachedOne() throws {
        let clock = ManualClock()

        let transport = makeTransport(replies: [
            makeResponse(try makeBody(BittensorApiFixtureDocuments.recommendations()), requestId: "req-newer"),
            makeResponse(try olderRecommendationsBody(), requestId: "req-older"),
            makeResponse(try olderRecommendationsBody(), requestId: "req-older-reload")
        ])

        let factory = makeFactory(transport: transport, clock: clock)

        let newer = try fetch(factory.createRecommendationsWrapper())
        clock.advance(by: 300)
        let afterExpiry = try fetch(factory.createRecommendationsWrapper())

        XCTAssertEqual(afterExpiry.requestId, "req-newer")
        XCTAssertEqual(afterExpiry.receivedAt, newer.receivedAt)
        XCTAssertTrue(afterExpiry.isFromExpiredCache)
        verify(transport, times(3)).createResponseWrapper(for: any())
    }

    func testAnOlderRankingGenerationDoesNotEvictTheNewerRecommendations() throws {
        let olderRanking = try mutatedBody(BittensorApiFixtureDocuments.rankedSubnets(), replacing: olderGeneration)

        let transport = makeTransport(replies: [
            makeResponse(try makeBody(BittensorApiFixtureDocuments.recommendations()), requestId: "req-newer"),
            makeResponse(olderRanking, requestId: "req-older"),
            makeResponse(olderRanking, requestId: "req-older-reload")
        ])

        let factory = makeFactory(transport: transport)

        _ = try fetch(factory.createRecommendationsWrapper())
        let ranking = try fetch(factory.createRankedSubnetsWrapper())
        let recommendations = try fetch(factory.createRecommendationsWrapper())

        XCTAssertEqual(ranking.requestId, "req-older-reload")
        XCTAssertEqual(recommendations.requestId, "req-newer")
        XCTAssertFalse(recommendations.isFromExpiredCache)
        verify(transport, times(3)).createResponseWrapper(for: any())
    }

    func testBackoffServesTheExpiredCachedValueWithoutCallingTheTransport() throws {
        let clock = ManualClock()

        let transport = makeTransport(replies: [
            makeResponse(try makeBody(BittensorApiFixtureDocuments.subnets()), requestId: "req-cached"),
            .failure(BittensorApiError.rateLimited(requestId: "req-limited"))
        ])

        let factory = makeFactory(transport: transport, clock: clock)

        let fresh = try fetch(factory.createSubnetsWrapper())
        clock.advance(by: 150)
        let limited = try fetch(factory.createSubnetsWrapper())
        let backingOff = try fetch(factory.createSubnetsWrapper())

        XCTAssertTrue(limited.isFromExpiredCache)
        XCTAssertTrue(backingOff.isFromExpiredCache)
        XCTAssertEqual(backingOff.requestId, "req-cached")
        XCTAssertEqual(backingOff.receivedAt, fresh.receivedAt)
        verify(transport, times(2)).createResponseWrapper(for: any())
    }

    private var olderGeneration: [(String, String)] {
        [
            (#""asOf":"2026-09-24T09:23:00Z""#, #""asOf":"2026-09-24T08:23:00Z""#),
            (#""id":"8ebc85abd0bbeb6f282302ac48909c3d""#, #""id":"0123456789abcdef0123456789abcdef""#)
        ]
    }

    private func olderRecommendationsBody() throws -> Data {
        try mutatedBody(BittensorApiFixtureDocuments.recommendations(), replacing: olderGeneration)
    }

    private func makeFactory(
        transport: BittensorApiTransportProtocol = BittensorApiFixtureTransport(),
        clock: ManualClock = ManualClock()
    ) -> BittensorApiOperationFactory {
        let cache = BittensorApiResponseCache(
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            timeProvider: { clock.now },
            jitterProvider: { 0 }
        )

        return BittensorApiOperationFactory(transport: transport, cache: cache, logger: Logger.shared)
    }

    private func makeTransport(
        replies: [Result<BittensorApiRawResponse, Error>],
        replyLatch: ReplyLatch? = nil
    ) -> MockBittensorApiTransportProtocol {
        let transport = MockBittensorApiTransportProtocol()
        let lock = NSLock()
        var remaining = replies

        stub(transport) { stub in
            when(stub.createResponseWrapper(for: any())).then { _ in
                lock.lock()
                let reply: Result<BittensorApiRawResponse, Error> = remaining.isEmpty
                    ? .failure(BittensorApiError.routeNotPublished)
                    : remaining.removeFirst()
                lock.unlock()

                let operation = AsyncClosureOperation<BittensorApiRawResponse> { completion in
                    guard let replyLatch else {
                        completion(reply)
                        return
                    }

                    replyLatch.hold { completion(reply) }
                }

                return CompoundOperationWrapper(targetOperation: operation)
            }
        }

        return transport
    }

    private func makeBody(_ document: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
    }

    private func mutatedBody(_ document: [String: Any], replacing replacements: [(String, String)]) throws -> Data {
        var json = String(decoding: try makeBody(document), as: UTF8.self)

        for (target, replacement) in replacements {
            XCTAssertTrue(json.contains(target))
            json = json.replacingOccurrences(of: target, with: replacement)
        }

        return Data(json.utf8)
    }

    private func makeResponse(_ body: Data, requestId: String) -> Result<BittensorApiRawResponse, Error> {
        .success(BittensorApiRawResponse(statusCode: 200, requestId: requestId, body: body))
    }

    private func completionExpectation<T>(for wrappers: [CompoundOperationWrapper<T>]) -> XCTestExpectation {
        let completed = expectation(description: "Bittensor API calls finished")
        completed.expectedFulfillmentCount = wrappers.count

        wrappers.forEach { wrapper in
            wrapper.targetOperation.completionBlock = { completed.fulfill() }
        }

        return completed
    }

    private func fetch<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let completed = completionExpectation(for: [wrapper])

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)

        wait(for: [completed], timeout: 10)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func fetchError<T>(_ wrapper: CompoundOperationWrapper<T>) -> BittensorApiError? {
        do {
            _ = try fetch(wrapper)

            return nil
        } catch {
            return error as? BittensorApiError
        }
    }
}

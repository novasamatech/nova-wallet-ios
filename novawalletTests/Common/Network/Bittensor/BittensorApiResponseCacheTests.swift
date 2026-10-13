import XCTest
import Operation_iOS
import NovaAuth
@testable import novawallet

final class BittensorApiResponseCacheTests: XCTestCase {
    private let queue = OperationQueue()
    private var admissions = 0
    private var fetches = 0
    private let key = BittensorApiCacheKey(method: "GET", path: "/subnets", query: [], bodyDigest: nil)
    private let route = BittensorApiRouteKey(method: "GET", pathTemplate: "/subnets", accountDigest: nil)

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let completed = expectation(description: "cache result")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: 10)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func job(
        origin: String = "https://first.test",
        generation: UInt64 = 1,
        admissionError: Error? = nil,
        result: Result<BittensorApiFetchedValue, Error>
    ) -> BittensorApiCacheJob {
        BittensorApiCacheJob(key: key, routeKey: route, currentInvalidationRevision: { 0 }, admit: { [self] in
            admissions += 1
            if let admissionError { return .createWithError(admissionError) }
            return .createWithResult(BittensorApiAdmission(
                scope: BittensorApiCacheScope(origin: origin, profile: 3, generation: generation, invalidationRevision: generation), endpoint: nil
            ))
        }, fetch: { [self] _ in
            fetches += 1
            return CompoundOperationWrapper(targetOperation: ClosureOperation { try result.get() })
        })
    }

    private var value: BittensorApiFetchedValue {
        BittensorApiFetchedValue(value: "seed", requestId: "req", cacheDirectives: .reusable(lifetime: 300), generation: nil)
    }

    func testSuccessfulBodiesNeverBypassAdmissionOrFetch() throws {
        let cache = BittensorApiResponseCache(operationQueue: queue, logger: Logger.shared)
        _ = try run(cache.createWrapper(for: job(result: .success(value))))
        _ = try run(cache.createWrapper(for: job(result: .success(value))))
        XCTAssertEqual(admissions, 2)
        XCTAssertEqual(fetches, 2)
        XCTAssertEqual(cache.peek(key, invalidationRevision: 0).value?.value as? String, "seed")
        XCTAssertFalse(cache.peek(key, invalidationRevision: 0).isFresh)
    }

    func testAdmissionFailureBlocksEvenWithAnExistingPresentationSeed() throws {
        let cache = BittensorApiResponseCache(operationQueue: queue, logger: Logger.shared)
        _ = try run(cache.createWrapper(for: job(result: .success(value))))
        XCTAssertThrowsError(try run(cache.createWrapper(for: job(
            admissionError: NovaAuthError.credentialUnavailable, result: .success(value)
        ))))
        XCTAssertEqual(admissions, 2)
        XCTAssertEqual(fetches, 1)
        XCTAssertNotNil(cache.peek(key, invalidationRevision: 0).value)
    }

    func testNegativeRouteStillRequiresAdmissionEveryTime() {
        let cache = BittensorApiResponseCache(operationQueue: queue, logger: Logger.shared)
        for _ in 0 ..< 2 {
            XCTAssertThrowsError(try run(cache.createWrapper(for: job(result: .failure(BittensorApiError.routeNotPublished)))))
        }
        XCTAssertEqual(admissions, 2)
        XCTAssertEqual(fetches, 1)
    }

    func testOriginChangeImmediatelyClearsSynchronousSeedsAndRejectsOlderScope() throws {
        let cache = BittensorApiResponseCache(operationQueue: queue, logger: Logger.shared)
        _ = try run(cache.createWrapper(for: job(result: .success(value))))
        cache.invalidate(before: 2)
        XCTAssertNil(cache.peek(key, invalidationRevision: 0).value)
        _ = try run(cache.createWrapper(for: job(origin: "https://second.test", generation: 2, result: .success(value))))
        XCTAssertThrowsError(try run(cache.createWrapper(for: job(result: .success(value)))))
        XCTAssertEqual(fetches, 2)
        XCTAssertNotNil(cache.peek(key, invalidationRevision: 0).value)
    }

    func testOldInFlightCompletionCannotRepopulateAfterInvalidation() throws {
        let cache = BittensorApiResponseCache(operationQueue: queue, logger: Logger.shared)
        let started = expectation(description: "old fetch started")
        var finish: ((Result<BittensorApiFetchedValue, Error>) -> Void)?
        let held = BittensorApiCacheJob(key: key, routeKey: route, currentInvalidationRevision: { 0 }, admit: {
            .createWithResult(BittensorApiAdmission(scope: BittensorApiCacheScope(origin: "https://first.test", profile: 3, generation: 1, invalidationRevision: 1), endpoint: nil))
        }, fetch: { _ in
            CompoundOperationWrapper(targetOperation: AsyncClosureOperation { completion in
                finish = completion
                started.fulfill()
            })
        })
        let old = cache.createWrapper(for: held)
        let completed = expectation(description: "old fetch completed")
        old.targetOperation.completionBlock = { completed.fulfill() }
        queue.addOperations(old.allOperations, waitUntilFinished: false)
        wait(for: [started], timeout: 10)
        cache.invalidate(before: 2)
        finish?(.success(value))
        wait(for: [completed], timeout: 10)
        XCTAssertThrowsError(try old.targetOperation.extractNoCancellableResultData())
        XCTAssertNil(cache.peek(key, invalidationRevision: 0).value)
    }
}

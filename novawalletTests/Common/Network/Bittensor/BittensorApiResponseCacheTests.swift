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

extension BittensorApiResponseCacheTests {
    func testDelayedOriginInvalidationPreservesCurrentAdmissionAndFlight() {
        runBoundedRace { [self] in
            let config = AuthConfigProvider()
            let invalidating = XCTestExpectation(description: "origin invalidation paused")
            let invalidated = XCTestExpectation(description: "origin invalidation delivered")
            let release = DispatchSemaphore(value: 0)
            defer { release.signal() }
            let (_, factory) = try makeAuthorizedFactory(config: config) {
                invalidating.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 20), .success)
            }
            _ = try raceResult(factory.createSubnetsWrapper())
            let old = try raceResult(factory.transport.createAdmissionWrapper(intent: .userInitiated))
            DispatchQueue.global().async {
                config.publish(origin: "https://second.test", revision: 2)
                invalidated.fulfill()
            }
            try awaitRace(invalidating)
            XCTAssertNil(factory.peekSubnets().value)

            let current = try raceResult(factory.transport.createAdmissionWrapper(intent: .userInitiated))
            XCTAssertGreaterThan(current.scope.generation, old.scope.generation)
            XCTAssertGreaterThan(current.scope.invalidationRevision, old.scope.invalidationRevision)
            let latch = BittensorApiOperationFactoryTests.ReplyLatch()
            defer { latch.release() }
            let started = XCTestExpectation(description: "current response held before cache delivery")
            let completed = XCTestExpectation(description: "current cache flight completed")
            let currentFlight = factory.cache.createWrapper(for: heldResponseJob(
                admission: current, transport: factory.transport, latch: latch, started: started
            ))
            currentFlight.targetOperation.completionBlock = { completed.fulfill() }
            queue.addOperations(currentFlight.allOperations, waitUntilFinished: false)
            try awaitRace(started)
            config.publish(origin: "https://second.test", revision: 3)
            XCTAssertEqual(factory.transport.invalidationRevision, current.scope.invalidationRevision)
            release.signal()
            try awaitRace(invalidated)
            latch.release()
            try awaitRace(completed)
            _ = try currentFlight.targetOperation.extractNoCancellableResultData()
            XCTAssertNotNil(factory.peekSubnets().value)
            _ = try raceResult(factory.createSubnetsWrapper())
            XCTAssertEqual(HostAuthURLProtocol.businessRequests.count, 3)
        }
    }

    func testDelayedResetInvalidationRejectsOldFlightAndQueuedAdmission() {
        runBoundedRace { [self] in
            let config = AuthConfigProvider()
            let invalidating = XCTestExpectation(description: "reset invalidation paused")
            let invalidated = XCTestExpectation(description: "reset invalidation delivered")
            let release = DispatchSemaphore(value: 0)
            defer { release.signal() }
            let (provider, factory) = try makeAuthorizedFactory(config: config) {
                invalidating.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 20), .success)
            }
            _ = try raceResult(factory.createSubnetsWrapper())
            let old = try raceResult(factory.transport.createAdmissionWrapper(intent: .userInitiated))
            let latch = BittensorApiOperationFactoryTests.ReplyLatch()
            defer { latch.release() }
            let started = XCTestExpectation(description: "old response held before cache delivery")
            let completed = XCTestExpectation(description: "old cache flight completed")
            let oldFlight = factory.cache.createWrapper(for: heldResponseJob(
                admission: old, transport: factory.transport, latch: latch, started: started
            ))
            oldFlight.targetOperation.completionBlock = { completed.fulfill() }
            queue.addOperations(oldFlight.allOperations, waitUntilFinished: false)
            try awaitRace(started)
            DispatchQueue.global().async {
                defer { invalidated.fulfill() }
                do { try provider.reset() } catch { XCTFail("Reset failed: \(error)") }
            }
            try awaitRace(invalidating)
            latch.release()
            try awaitRace(completed)
            XCTAssertThrowsError(try oldFlight.targetOperation.extractNoCancellableResultData()) { error in
                guard case BittensorApiError.attestationUnavailable = error else {
                    return XCTFail("Expected stale admission rejection, received \(error)")
                }
            }
            XCTAssertNil(factory.peekSubnets().value)
            let queued = BittensorApiCacheJob(
                key: key, routeKey: route,
                currentInvalidationRevision: { factory.transport.invalidationRevision },
                admit: { .createWithResult(old) },
                fetch: { _ in
                    XCTFail("An old queued admission must not start a fetch")
                    return .createWithResult(self.value)
                }
            )
            XCTAssertThrowsError(try raceResult(factory.cache.createWrapper(for: queued))) { error in
                guard case BittensorApiError.attestationUnavailable = error else {
                    return XCTFail("Expected stale admission rejection, received \(error)")
                }
            }
            _ = try raceResult(factory.createSubnetsWrapper())
            release.signal()
            try awaitRace(invalidated)
            XCTAssertNotNil(factory.peekSubnets().value)
            _ = try raceResult(factory.createSubnetsWrapper())
            XCTAssertEqual(HostAuthURLProtocol.businessRequests.count, 4)
        }
    }
}

private extension BittensorApiResponseCacheTests {
    func runBoundedRace(_ work: @escaping () throws -> Void) {
        let completed = expectation(description: "cache invalidation race completed")
        DispatchQueue.global().async {
            defer { completed.fulfill() }
            do { try work() } catch { XCTFail("Cache invalidation race failed: \(error)") }
        }
        wait(for: [completed], timeout: 30)
    }

    func awaitRace(_ expectation: XCTestExpectation) throws {
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            XCTFail("Timed out waiting for \(expectation.expectationDescription)")
            throw BaseOperationError.parentOperationCancelled
        }
    }

    func raceResult<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let completed = XCTestExpectation(description: "authorized cache operation completed")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        try awaitRace(completed)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func makeAuthorizedFactory(
        config: AuthConfigProvider,
        willInvalidate: @escaping () -> Void
    ) throws -> (NovaAuthFacade, BittensorApiOperationFactory) {
        HostAuthURLProtocol.reset()
        let body = try JSONSerialization.data(withJSONObject: BittensorApiFixtureDocuments.subnets())
        HostAuthURLProtocol.business = { _ in
            .init(status: 200, headers: ["Cache-Control": "no-store", "Content-Type": "application/json"], body: body)
        }
        let auth = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let provider = NovaAuthFacade(
            configProvider: config,
            client: auth.client,
            contextInvalidationID: { auth.client.contextInvalidationID },
            activate: { try auth.client.activate(origin: $0) },
            reset: { try auth.client.reset() }
        )
        provider.addContextObserver(self, closure: willInvalidate)
        let transport = BittensorAuthorizedTransport(provider: provider, operationQueue: queue)
        let cache = BittensorApiResponseCache(operationQueue: queue, logger: Logger.shared)
        let factory = BittensorApiOperationFactory(
            transport: transport, cache: cache, logger: Logger.shared, intent: .userInitiated
        )
        return (provider, factory)
    }

    func heldResponseJob(
        admission: BittensorApiAdmission,
        transport: BittensorApiTransportProtocol,
        latch: BittensorApiOperationFactoryTests.ReplyLatch,
        started: XCTestExpectation
    ) -> BittensorApiCacheJob {
        BittensorApiCacheJob(
            key: key, routeKey: route,
            currentInvalidationRevision: { transport.invalidationRevision },
            admit: { .createWithResult(admission) },
            fetch: { admitted in
                let request = BittensorApiRequest(
                    method: .get, path: "/subnets", pathTemplate: "/subnets",
                    queryItems: [], jsonBody: nil, intent: .userInitiated
                )
                let response = transport.createResponseWrapper(for: request, admission: admitted)
                let hold = AsyncClosureOperation<BittensorApiFetchedValue> { completion in
                    do {
                        let raw = try response.targetOperation.extractNoCancellableResultData()
                        let fetched = BittensorApiFetchedValue(
                            value: try JSONDecoder().decode(BittensorApi.SubnetCollection.self, from: raw.body),
                            requestId: raw.requestId, cacheDirectives: raw.cacheDirectives, generation: nil
                        )
                        latch.hold { completion(.success(fetched)) }
                        started.fulfill()
                    } catch { completion(.failure(error)) }
                }
                hold.addDependency(response.targetOperation)
                return response.insertingTail(operation: hold)
            }
        )
    }
}

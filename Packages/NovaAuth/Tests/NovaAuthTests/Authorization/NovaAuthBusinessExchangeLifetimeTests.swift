import XCTest
import Operation_iOS
@testable import NovaAuth

final class NovaAuthBusinessExchangeLifetimeTests: LifecycleTestCase {
    func testIssuerReleasesCompletedGetOperations() throws {
        try assertReleased(scenario: .get)
    }

    func testIssuerReleasesCompletedPostOperations() throws {
        try assertReleased(scenario: .post)
    }

    func testIssuerReleasesFailedOperations() throws {
        try assertReleased(scenario: .failure)
    }

    func testIssuerReleasesBothChildrenAfterInvalidTokenReplay() throws {
        try assertReleased(scenario: .replay)
    }

    func testIssuerReleasesBothChildrenAfterFinalDenial() throws {
        try assertReleased(scenario: .denied)
    }

    func testIssuerReleasesOperationsAfterCancellationSuppressesResult() throws {
        try assertReleased(scenario: .cancelled)
    }
}

private extension NovaAuthBusinessExchangeLifetimeTests {
    enum Scenario { case get, post, failure, replay, denied, cancelled }

    func assertReleased(
        scenario: Scenario,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered(withToken: true)
        let http = ExchangeLifetimeHTTP(base: harness.http)
        let client = harness.makeAuth(http: http)
        _ = try client.activate(origin: harness.origin)
        let pending = LifecyclePending<NovaAuthResponse>()
        let started = XCTestExpectation(description: "business HTTP started")
        harness.http.handler = { request, completion in
            if scenario == .cancelled {
                pending.start(completion)
                started.fulfill()
                return
            }
            completion(Result {
                if scenario == .failure { throw URLError(.notConnectedToInternet) }
                let first = harness.http.requests.count == 1
                if (scenario == .replay && first) || scenario == .denied {
                    return try LifecycleHTTP.response(
                        request: request,
                        status: 401,
                        headers: NovaAuthRecoveryTests.denialHeaders,
                        body: NovaAuthRecoveryTests.denialBody
                    )
                }
                return try LifecycleHTTP.response(request: request)
            })
        }
        defer { harness.http.handler = nil }
        let released = expectation(description: "exchange and outer operation release their caller closure")
        let body = scenario == .post ? Data(#"{"events":[{"value":1}]}"#.utf8) : nil
        let request = try harness.request(context: context, method: scenario == .post ? .post : .get, body: body)
        weak var outer: Operation?
        try autoreleasepool {
            let lifetime = ExchangeLifetime(onRelease: { released.fulfill() })
            let wrapper = client.createResponseWrapper(for: request, beforeSend: {
                withExtendedLifetime(lifetime) {}
            })
            outer = wrapper.targetOperation
            switch scenario {
            case .cancelled:
                try cancelAfterSend(wrapper, harness: harness, started: started, pending: pending)
            case .failure:
                assertError(.transport(.notConnectedToInternet), wrapper, on: harness.callers, file: file, line: line)
            case .denied:
                assertError(.authorizationDenied(requestID: "req-one"), wrapper, on: harness.callers, file: file, line: line)
            case .get, .post, .replay:
                let response = try execute(wrapper, on: harness.callers)
                XCTAssertEqual(response.response.statusCode, 200, file: file, line: line)
            }
        }
        drainQueues(harness)
        wait(for: [released], timeout: 5)
        let children = http.operations
        let replayed = scenario == .replay || scenario == .denied
        XCTAssertEqual(children.count, replayed ? 2 : 1, file: file, line: line)
        XCTAssertEqual(harness.http.requests.count, children.count, file: file, line: line)
        XCTAssertEqual(harness.bootstrap.tokens.count, replayed ? 1 : 0, file: file, line: line)
        XCTAssertEqual(harness.http.requests.first?.httpBody, body, file: file, line: line)
        XCTAssertNil(outer, file: file, line: line)
        for child in children {
            XCTAssertNil(child.operation, file: file, line: line)
        }
        withExtendedLifetime(client) {}
    }

    func cancelAfterSend(
        _ wrapper: CompoundOperationWrapper<NovaAuthResponse>,
        harness: LifecycleHarness,
        started: XCTestExpectation,
        pending: LifecyclePending<NovaAuthResponse>
    ) throws {
        let cancelled = expectation(description: "outer operation cancelled")
        wrapper.targetOperation.completionBlock = { cancelled.fulfill() }
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [started], timeout: 5)
        wrapper.cancel()
        wait(for: [cancelled], timeout: 5)
        XCTAssertTrue(wrapper.targetOperation.isCancelled)
        XCTAssertNil(wrapper.targetOperation.result)
        let request = try XCTUnwrap(harness.http.requests.first)
        pending.resolve(.success(try LifecycleHTTP.response(request: request)))
        XCTAssertNil(wrapper.targetOperation.result)
    }

    func drainQueues(_ harness: LifecycleHarness) {
        let drained = expectation(description: "operation queues drained")
        let queues = [harness.ownerQueue, harness.bootstrapQueue, harness.requestQueue, harness.callers]
        drained.expectedFulfillmentCount = queues.count
        queues.forEach { $0.addBarrierBlock { drained.fulfill() } }
        wait(for: [drained], timeout: 5)
    }
}

private final class ExchangeLifetime {
    let onRelease: () -> Void

    init(onRelease: @escaping () -> Void) { self.onRelease = onRelease }
    deinit { onRelease() }
}

private final class ExchangeWeakOperation {
    weak var operation: Operation?

    init(_ operation: Operation) { self.operation = operation }
}

private final class ExchangeLifetimeHTTP: NovaAuthHTTPProtocol {
    let base: LifecycleHTTP
    private let lock = NSLock()
    private var tracked: [ExchangeWeakOperation] = []
    var operations: [ExchangeWeakOperation] { lock.novaAuthLocked { tracked } }

    init(base: LifecycleHTTP) { self.base = base }

    func clearReadCache() { base.clearReadCache() }

    func createResponseWrapper(
        for request: URLRequest,
        kind: NovaAuthHTTPKind,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        let wrapper = base.createResponseWrapper(for: request, kind: kind, beforeSend: beforeSend)
        lock.novaAuthLocked { tracked.append(contentsOf: wrapper.allOperations.map(ExchangeWeakOperation.init)) }
        return wrapper
    }
}

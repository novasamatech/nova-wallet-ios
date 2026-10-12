import XCTest
import Operation_iOS
@testable import NovaAuth

final class NovaAuthBusinessExchangeTests: LifecycleTestCase {
    private enum CallerError: Error { case consentWithdrawn }

    func testCallerFailuresPreserveTheirTypeAndDoNotApplyBusinessBackoff() throws {
        for callerError in [CallerError.consentWithdrawn, URLError(.networkConnectionLost)] as [Error] {
            let harness = try LifecycleHarness()
            let (auth, context) = try harness.registered(withToken: true)
            let request = try harness.request(context: context)
            XCTAssertThrowsError(try execute(auth.createResponseWrapper(for: request, beforeSend: {
                throw callerError
            }), on: harness.callers)) { error in
                if callerError is CallerError { XCTAssertTrue(error is CallerError) }
                else { XCTAssertEqual((error as? URLError)?.code, .networkConnectionLost) }
            }
            XCTAssertTrue(harness.http.requests.isEmpty)
            try execute(auth.createResponseWrapper(for: request, beforeSend: {}), on: harness.callers)
            XCTAssertEqual(harness.http.requests.count, 1)
            XCTAssertTrue(harness.bootstrap.tokens.isEmpty)
        }
    }

    func testInvalidationBeforeSendReadmitsOnceWithoutChangingPostBody() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered(withToken: true)
        let http = BoundaryHTTP(base: harness.http)
        let auth = harness.makeAuth(http: http)
        _ = try auth.activate(origin: harness.origin)
        http.beforeCreate = { try harness.tokens.removeAll() }
        let body = Data(#"{"events":[{"value":1}]}"#.utf8)
        let request = try harness.request(context: context, method: .post, body: body)
        try execute(auth.createResponseWrapper(for: request, beforeSend: {}), on: harness.callers)
        XCTAssertEqual(harness.http.requests.map(\.httpBody), [body])
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
        XCTAssertEqual(http.creations, 2)
    }

    func testRepeatedUnsentInvalidationStopsWithoutAnyNetworkSend() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered(withToken: true)
        let http = BoundaryHTTP(base: harness.http)
        let auth = harness.makeAuth(http: http)
        _ = try auth.activate(origin: harness.origin)
        http.repeatsBoundary = true
        http.beforeCreate = { try harness.tokens.removeAll() }
        assertError(.credentialUnavailable, auth.createResponseWrapper(for: try harness.request(context: context), beforeSend: {}), on: harness.callers)
        XCTAssertTrue(harness.http.requests.isEmpty)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
        XCTAssertEqual(http.creations, 2)
    }

    func testCancellationDuringWrapperCreationNeverEnqueuesCancelledChild() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered(withToken: true)
        let http = BoundaryHTTP(base: harness.http)
        let auth = harness.makeAuth(http: http)
        _ = try auth.activate(origin: harness.origin)
        let wrapper = auth.createResponseWrapper(for: try harness.request(context: context), beforeSend: {})
        let cancelled = expectation(description: "cancelled during child creation")
        http.beforeCreate = { wrapper.cancel(); cancelled.fulfill() }
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [cancelled], timeout: 5)
        drain(harness.ownerQueue)
        XCTAssertTrue(harness.http.requests.isEmpty)
        XCTAssertEqual(harness.requestQueue.operationCount, 0)
    }

    func testFastCompletionCannotReplaceNewChildCancellationWithOldAction() throws {
        let cancellation = NovaAuthCancellation()
        let queue = OperationQueue()
        let secondStarted = expectation(description: "second child starts")
        let secondCancelled = expectation(description: "second child owns cancellation")
        let second = AsyncClosureOperation<Void>(operationClosure: { _ in
            secondStarted.fulfill()
        }, cancelationClosure: { secondCancelled.fulfill() })
        let first = ClosureOperation<Void> {}
        first.completionBlock = {
            do { try cancellation.enqueue(CompoundOperationWrapper(targetOperation: second), on: queue) }
            catch { XCTFail("unexpected cancellation") }
        }
        try cancellation.enqueue(CompoundOperationWrapper(targetOperation: first), on: queue)
        wait(for: [secondStarted], timeout: 5)
        cancellation.cancel()
        wait(for: [secondCancelled], timeout: 5)
    }
}

private final class BoundaryHTTP: NovaAuthHTTPProtocol {
    let base: LifecycleHTTP
    var beforeCreate: (() throws -> Void)?
    var repeatsBoundary = false
    private(set) var creations = 0

    init(base: LifecycleHTTP) { self.base = base }
    func clearReadCache() { base.clearReadCache() }
    func createResponseWrapper(
        for request: URLRequest,
        kind: NovaAuthHTTPKind,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        creations += 1
        let boundary = beforeCreate
        if !repeatsBoundary { beforeCreate = nil }
        do { try boundary?() }
        catch { return .createWithError(error) }
        return base.createResponseWrapper(for: request, kind: kind, beforeSend: beforeSend)
    }
}

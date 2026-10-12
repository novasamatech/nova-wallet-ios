import XCTest
import Operation_iOS
@testable import NovaAuth

final class NovaAuthConcurrencyTests: LifecycleTestCase {
    func testConcurrentAnalyticsAndReadMissesUseOneFlightWithSaturatedCallerQueue() throws {
        let harness = try LifecycleHarness()
        harness.callers.maxConcurrentOperationCount = 2
        let (auth, context) = try harness.registered()
        let pending = LifecyclePending<NovaAuthTokenResponse>()
        let issued = expectation(description: "token POST started independently")
        pending.onStart = { issued.fulfill() }
        harness.bootstrap.onToken = pending.start
        let read = auth.createResponseWrapper(for: try harness.request(context: context), beforeSend: {})
        let analytics = auth.createResponseWrapper(for: try harness.request(context: context, method: .post, body: Data("{\"events\":[]}".utf8)), beforeSend: {})
        let completed = expectation(description: "both protected requests complete")
        completed.expectedFulfillmentCount = 2
        read.targetOperation.completionBlock = { completed.fulfill() }
        analytics.targetOperation.completionBlock = { completed.fulfill() }
        harness.callers.addOperations(read.allOperations + analytics.allOperations, waitUntilFinished: false)
        wait(for: [issued], timeout: 5)
        drain(harness.ownerQueue)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 1)
        XCTAssertEqual(harness.apple.assertions.count, 1)
        pending.resolve(.success(harness.bootstrap.tokenResult))
        wait(for: [completed], timeout: 5)
        XCTAssertNoThrow(try read.targetOperation.extractNoCancellableResultData())
        XCTAssertNoThrow(try analytics.targetOperation.extractNoCancellableResultData())
        XCTAssertEqual(harness.http.requests.count, 2)
        XCTAssertEqual(Set(harness.http.requests.compactMap { $0.value(forHTTPHeaderField: "Authorization") }).count, 1)
    }

    func testUsableBusinessRequestsRunInParallel() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        let lock = NSLock()
        var callbacks: [(Result<NovaAuthResponse, Error>) -> Void] = []
        var requests: [URLRequest] = []
        let sent = expectation(description: "both requests sent before either response")
        sent.expectedFulfillmentCount = 2
        harness.http.handler = { request, completion in
            lock.novaAuthLocked { requests.append(request); callbacks.append(completion) }
            sent.fulfill()
        }
        let wrappers = try [harness.request(context: context), harness.request(context: context, method: .head)]
            .map { auth.createResponseWrapper(for: $0, beforeSend: {}) }
        let done = expectation(description: "parallel reads complete")
        done.expectedFulfillmentCount = 2
        wrappers.forEach { $0.targetOperation.completionBlock = { done.fulfill() } }
        harness.callers.addOperations(wrappers.flatMap(\.allOperations), waitUntilFinished: false)
        wait(for: [sent], timeout: 5)
        for (request, callback) in zip(requests, callbacks) {
            callback(.success(try LifecycleHTTP.response(request: request)))
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
    }

    func testNoSecondAssertionWhileFirstTokenPostIsPending() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let pending = LifecyclePending<NovaAuthTokenResponse>()
        let sent = expectation(description: "first token POST pending")
        pending.onStart = { sent.fulfill() }
        harness.bootstrap.onToken = pending.start
        let first = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        harness.callers.addOperations(first.allOperations, waitUntilFinished: false)
        wait(for: [sent], timeout: 5)
        let second = auth.createAdmissionWrapper(in: context, intent: .background)
        let done = expectation(description: "second demand uses first issuance")
        second.targetOperation.completionBlock = { done.fulfill() }
        harness.callers.addOperations(second.allOperations, waitUntilFinished: false)
        drain(harness.ownerQueue)
        XCTAssertEqual(harness.apple.assertions.count, 1)
        pending.resolve(.success(harness.bootstrap.tokenResult))
        wait(for: [done], timeout: 5)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
    }

    func testConcurrentDenialsShareOneRenewalAndKeepEachBusinessRetryBounded() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        let lock = NSLock()
        var original: [(URLRequest, (Result<NovaAuthResponse, Error>) -> Void)] = []
        let sent = expectation(description: "both original requests reached origin")
        sent.expectedFulfillmentCount = 2
        harness.http.handler = { request, completion in
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer original-current-bearer" {
                lock.novaAuthLocked { original.append((request, completion)) }
                sent.fulfill()
            } else { completion(Result { try LifecycleHTTP.response(request: request) }) }
        }
        let pending = LifecyclePending<NovaAuthTokenResponse>()
        let renewing = expectation(description: "shared renewal pending")
        pending.onStart = { renewing.fulfill() }
        harness.bootstrap.onToken = pending.start
        let requests = try [harness.request(context: context), harness.request(context: context, method: .post, body: Data("{}".utf8))]
        let wrappers = requests.map { auth.createResponseWrapper(for: $0, beforeSend: {}) }
        let done = expectation(description: "both retries complete")
        done.expectedFulfillmentCount = 2
        wrappers.forEach { $0.targetOperation.completionBlock = { done.fulfill() } }
        harness.callers.addOperations(wrappers.flatMap(\.allOperations), waitUntilFinished: false)
        wait(for: [sent], timeout: 5)
        for (request, callback) in original {
            callback(.success(try LifecycleHTTP.response(
                request: request,
                status: 401,
                headers: NovaAuthRecoveryTests.denialHeaders,
                body: NovaAuthRecoveryTests.denialBody
            )))
        }
        wait(for: [renewing], timeout: 5)
        pending.resolve(.success(harness.bootstrap.tokenResult))
        wait(for: [done], timeout: 5)
        for wrapper in wrappers { XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData()) }
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
        XCTAssertEqual(harness.http.requests.count, 4)
    }
}

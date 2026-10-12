import XCTest
@testable import NovaAuth

final class NovaAuthReaderTests: LifecycleTestCase {
    func testReaderUsesSharedPersistedBearerIncludingEarlyWindowWithoutIssuing() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered(withToken: true)
        harness.clock.advance(460)
        let reader = harness.makeReader()
        XCTAssertEqual(try execute(reader.createContextWrapper(), on: harness.callers), context)
        try execute(reader.createResponseWrapper(for: harness.request(context: context), beforeSend: {}), on: harness.callers)
        XCTAssertEqual(harness.http.requests.count, 1)
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testMissingExpiredRebootedUnreadableOrFutureRecordNeverSendsOriginRequest() throws {
        for mode in 0 ..< 5 {
            let harness = try LifecycleHarness()
            let (_, context) = try harness.registered(withToken: true)
            switch mode {
            case 0: try harness.tokens.removeAll()
            case 1: harness.clock.advance(595)
            case 2: harness.clock.reboot()
            case 3: harness.tokens.failLoad = true
            default: try harness.tokens.replace(harness.record(context: context, start: 200))
            }
            let reader = harness.makeReader()
            assertError(
                mode == 3 ? .storageUnavailable : .credentialUnavailable,
                reader.createResponseWrapper(for: try harness.request(context: context), beforeSend: {}),
                on: harness.callers
            )
            XCTAssertEqual(harness.http.requests.count, 0)
            XCTAssertEqual(harness.bootstrap.tokens.count, 0)
        }
    }

    func testReaderCannotUseContextFromEarlierAuthGeneration() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered(withToken: true)
        let next = NovaAuthContext(origin: context.origin, generation: context.generation + 1)
        try harness.tokens.replace(harness.record(context: next))
        assertError(.generationChanged, harness.makeReader().createResponseWrapper(for: try harness.request(context: context), beforeSend: {}), on: harness.callers)
        XCTAssertEqual(harness.http.requests.count, 0)
    }

    func testReaderDenialWithoutMainAppReplacementFailsWithoutRenewing() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered(withToken: true)
        harness.http.handler = { request, completion in
            completion(Result { try LifecycleHTTP.response(
                request: request,
                status: 401,
                headers: NovaAuthRecoveryTests.denialHeaders,
                body: NovaAuthRecoveryTests.denialBody
            ) })
        }
        assertError(.credentialUnavailable, harness.makeReader().createResponseWrapper(for: try harness.request(context: context), beforeSend: {}), on: harness.callers)
        XCTAssertNil(try harness.tokens.load())
        XCTAssertEqual(harness.http.requests.count, 1)
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
    }

    func testLateExtensionDenialCannotDeleteMainReplacementAndMayRetryItOnce() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered(withToken: true)
        let newer = harness.record(context: context, bearer: "new-main-app-bearer")
        harness.http.handler = { request, completion in
            completion(Result {
                if harness.http.requests.count == 1 {
                    try harness.tokens.replace(newer)
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
        try execute(harness.makeReader().createResponseWrapper(for: harness.request(context: context), beforeSend: {}), on: harness.callers)
        XCTAssertEqual(try harness.tokens.load(), newer)
        XCTAssertEqual(harness.http.requests.count, 2)
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
    }
}

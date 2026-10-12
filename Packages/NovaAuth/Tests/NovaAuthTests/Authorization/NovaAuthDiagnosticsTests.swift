import XCTest
import SDKLogger
@testable import NovaAuth

final class NovaAuthDiagnosticsTests: LifecycleTestCase {
    func testFailureDiagnosticsKeepStageStatusAndRequestIDWithoutRawServerData() {
        let logged = expectation(description: "bounded failure logged")
        let logger = AuthRecordingLogger { logged.fulfill() }
        NovaAuthDiagnostics.failure(.bootstrap(NovaAuthServerError(
            statusCode: 503,
            code: "SECRET_PROVIDER_PAYLOAD",
            requestID: "request-503",
            retryAfter: 905
        )), phase: .tokenChallenge, logger: logger)
        wait(for: [logged], timeout: 5)
        let message = logger.messages.joined()
        XCTAssertTrue(message.contains("phase=tokenChallenge"))
        XCTAssertTrue(message.contains("reason=bootstrap"))
        XCTAssertTrue(message.contains("status=503"))
        XCTAssertTrue(message.contains("requestID=request-503"))
        XCTAssertTrue(message.contains("retryAfter=905"))
        XCTAssertFalse(message.contains("SECRET_PROVIDER_PAYLOAD"))
        XCTAssertEqual(logger.levels, ["warning"])
    }

    func testInvalidDiagnosticMetadataIsDiscardedAndLoggerRunsOutsideCallerLock() {
        let logged = expectation(description: "logger can acquire caller lock")
        let lock = NSLock()
        let logger = AuthRecordingLogger {
            lock.lock()
            lock.unlock()
            logged.fulfill()
        }
        lock.lock()
        NovaAuthDiagnostics.log(.storageRecovery, logger: logger, requestID: "SECRET\nHEADER", retryAfter: .infinity)
        lock.unlock()
        wait(for: [logged], timeout: 5)
        XCTAssertEqual(logger.messages, ["NovaAuth transition=storageRecovery"])
    }

    func testRecoveredDenialLogsFirstRequestIDWithoutBearerOrIdentity() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered(withToken: true)
        let recovered = expectation(description: "first denial retained in recovery diagnostic")
        let logger = AuthRecordingLogger()
        logger.onMessage = { if $0.contains("transition=bearerRecovered") { recovered.fulfill() } }
        let auth = NovaAuth(dependencies: NovaAuthDependencies(
            appAttest: harness.apple, identityStore: harness.identity, tokenStore: harness.tokens,
            clock: harness.clock, random: harness.random, bootstrap: harness.bootstrap, http: harness.http,
            ownerQueue: harness.ownerQueue, bootstrapQueue: harness.bootstrapQueue,
            requestQueue: harness.requestQueue, appIdentity: harness.appIdentity, logger: logger
        ))
        _ = try auth.activate(origin: harness.origin)
        harness.http.handler = { request, completion in
            completion(Result {
                if harness.http.requests.count == 1 {
                    return try LifecycleHTTP.response(
                        request: request, status: 401, headers: NovaAuthRecoveryTests.denialHeaders,
                        body: NovaAuthRecoveryTests.denialBody
                    )
                }
                return try LifecycleHTTP.response(request: request)
            })
        }
        try execute(auth.createResponseWrapper(for: harness.request(context: context), beforeSend: {}), on: harness.callers)
        wait(for: [recovered], timeout: 5)
        let messages = logger.messages.joined(separator: "\n")
        XCTAssertTrue(messages.contains("transition=bearerRecovered requestID=req-one"))
        XCTAssertFalse(messages.contains("original-current-bearer"))
        XCTAssertFalse(messages.contains(harness.bootstrap.tokenResult.accessToken))
        XCTAssertFalse(messages.contains(harness.identity.state?.identity?.clientID ?? "missing-identity"))
        XCTAssertFalse(messages.contains("Authorization"))
    }
}

private final class AuthRecordingLogger: SDKLoggerProtocol {
    private let lock = NSLock()
    private var recorded: [(String, String)] = []
    private let onLog: () -> Void
    var onMessage: ((String) -> Void)?
    var messages: [String] { lock.novaAuthLocked { recorded.map(\.1) } }
    var levels: [String] { lock.novaAuthLocked { recorded.map(\.0) } }

    init(onLog: @escaping () -> Void = {}) { self.onLog = onLog }
    func verbose(message: String, file _: String, function _: String, line _: Int) { record("verbose", message) }
    func debug(message: String, file _: String, function _: String, line _: Int) { record("debug", message) }
    func info(message: String, file _: String, function _: String, line _: Int) { record("info", message) }
    func warning(message: String, file _: String, function _: String, line _: Int) { record("warning", message) }
    func error(message: String, file _: String, function _: String, line _: Int) { record("error", message) }

    private func record(_ level: String, _ message: String) {
        lock.novaAuthLocked { recorded.append((level, message)) }
        onMessage?(message)
        onLog()
    }
}

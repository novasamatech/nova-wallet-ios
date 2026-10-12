import Foundation
import XCTest
import Operation_iOS
@testable import NovaAuth

final class LifecycleHarness {
    let clock = LifecycleClock()
    let random = LifecycleRandom()
    let identity = LifecycleIdentityStore()
    let tokens = LifecycleTokenStore()
    let apple = LifecycleApple()
    let bootstrap = LifecycleBootstrap()
    let http = LifecycleHTTP()
    let ownerQueue = OperationQueue()
    let bootstrapQueue = OperationQueue()
    let requestQueue = OperationQueue()
    let callers = OperationQueue()
    let origin: NovaAuthOrigin
    let appIdentity: NovaAuthAppIdentity

    init() throws {
        origin = try NovaAuthOrigin("https://auth.example.com")
        appIdentity = try NovaAuthAppIdentity(appID: "PREFIX.io.nova.wallet", environment: .development)
        ownerQueue.maxConcurrentOperationCount = 1
        bootstrapQueue.maxConcurrentOperationCount = 4
        requestQueue.maxConcurrentOperationCount = 4
        callers.maxConcurrentOperationCount = 8
    }

    func makeAuth(http: NovaAuthHTTPProtocol? = nil) -> NovaAuth {
        NovaAuth(dependencies: NovaAuthDependencies(
            appAttest: apple,
            identityStore: identity,
            tokenStore: tokens,
            clock: clock,
            random: random,
            bootstrap: bootstrap,
            http: http ?? self.http,
            ownerQueue: ownerQueue,
            bootstrapQueue: bootstrapQueue,
            requestQueue: requestQueue,
            appIdentity: appIdentity,
            logger: nil
        ))
    }

    func makeReader(http: NovaAuthHTTPProtocol? = nil) -> NovaAuthReader {
        NovaAuthReader(dependencies: NovaAuthReaderDependencies(
            origin: origin,
            tokenStore: tokens,
            clock: clock,
            http: http ?? self.http,
            requestQueue: requestQueue
        ))
    }

    func registered(withToken: Bool = false) throws -> (NovaAuth, NovaAuthContext) {
        let context = NovaAuthContext(origin: origin, generation: 1)
        identity.state = NovaAuthInstallationState(
            version: 1,
            context: context,
            requiresUserAction: false,
            identity: NovaAuthInstallationIdentity(
                clientID: "11111111-1111-4111-8111-111111111111",
                keyID: Data(repeating: 1, count: 32).base64EncodedString(),
                registration: .registered
            )
        )
        if withToken { try tokens.replace(record(context: context)) }
        let auth = makeAuth()
        _ = try auth.activate(origin: origin)
        return (auth, context)
    }

    func record(
        context: NovaAuthContext,
        bearer: String = "original-current-bearer",
        start: Double = 100,
        boot: String = "boot-a",
        lifetime: Int64 = 600,
        threshold: Int = 140
    ) -> NovaAuthTokenRecord {
        NovaAuthTokenRecord(
            version: 1,
            context: context,
            flow: "bittensor-read",
            clientID: identity.state?.identity?.clientID ?? "11111111-1111-4111-8111-111111111111",
            accessToken: bearer,
            issuedAt: 1000,
            expiresAt: 1000 + lifetime,
            issuanceStart: NovaAuthTime(bootID: boot, continuousSeconds: start),
            earlyRefreshSeconds: threshold
        )
    }

    func request(
        context: NovaAuthContext,
        method: NovaAuthMethod = .get,
        body: Data? = nil,
        path: String? = nil,
        intent: NovaAuthRequestIntent = .userInitiated
    ) throws -> NovaAuthRequest {
        try NovaAuthRequest(
            context: context,
            method: method,
            path: path ?? (method == .post ? "/v1/analytics/events" : "/v1/bittensor/profile-3/subnets"),
            queryItems: [],
            body: body,
            contentType: method == .post ? "application/json" : nil,
            intent: intent
        )
    }
}

class LifecycleTestCase: XCTestCase {
    @discardableResult
    func execute<Value>(
        _ wrapper: CompoundOperationWrapper<Value>,
        on queue: OperationQueue,
        file _: StaticString = #filePath,
        line _: UInt = #line
    ) throws -> Value {
        let done = expectation(description: "operation completed")
        wrapper.targetOperation.completionBlock = { done.fulfill() }
        queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [done], timeout: 5)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func assertError<Value>(
        _ expected: NovaAuthError,
        _ wrapper: CompoundOperationWrapper<Value>,
        on queue: OperationQueue,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            _ = try execute(wrapper, on: queue)
            XCTFail("Expected a typed authentication error", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? NovaAuthError, expected, file: file, line: line)
        }
    }

    func drain(_ queue: OperationQueue) {
        let done = expectation(description: "owner transitions drained")
        queue.addOperation { done.fulfill() }
        wait(for: [done], timeout: 5)
    }

    func observeFlight(_ auth: NovaAuth) -> XCTestExpectation {
        let done = expectation(description: "issuance flight completed")
        auth.gate.novaAuthLocked { auth.flight?.waiters[UUID()] = { _ in done.fulfill() } }
        return done
    }
}

import Foundation
import Operation_iOS
import XCTest
@testable import NovaAnalytics
@testable import NovaAuth
@testable import novawallet

final class HostAuthIdentityStore: NovaAuthIdentityStoreProtocol {
    var state: NovaAuthInstallationState?
    var loadError: Error?
    var saveError: Error?
    func load() throws -> NovaAuthInstallationState? {
        if let loadError { throw loadError }
        return state
    }

    func save(_ state: NovaAuthInstallationState) throws {
        if let saveError { throw saveError }
        self.state = state
        loadError = nil
    }

    func markResetPending() throws { throw NovaAuthError.storageUnavailable }
}

final class HostAuthTokenStore: NovaAuthTokenStoreProtocol {
    private let lock = NSLock()
    private var record: NovaAuthTokenRecord?
    func load() throws -> NovaAuthTokenRecord? { lock.lock(); defer { lock.unlock() }; return record }
    func replace(_ record: NovaAuthTokenRecord) throws { lock.lock(); self.record = record; lock.unlock() }
    func remove(ifMatching record: NovaAuthTokenRecord) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard self.record == record else { return false }
        self.record = nil
        return true
    }

    func removeAll() throws { lock.lock(); record = nil; lock.unlock() }
}

final class HostAuthApple: NovaAuthAppAttestProtocol {
    var isSupported = true
    private(set) var attestations = 0
    private(set) var assertions = 0
    func isBusy(keyID _: String) -> Bool { false }
    func createKeyWrapper() -> CompoundOperationWrapper<String> { .createWithResult(Data(repeating: 1, count: 32).base64EncodedString()) }
    func createAttestationWrapper(
        keyID _: String,
        clientDataHash _: Data,
        beforeAttest: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<Data> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { [self] in
            try beforeAttest()
            attestations += 1
            return Data([1, 2, 3])
        })
    }

    func createAssertionWrapper(keyID _: String, clientDataHash _: Data) -> CompoundOperationWrapper<Data> {
        assertions += 1
        return .createWithResult(Data([4, 5, 6]))
    }
}

struct HostAuthRandom: NovaAuthRandomProtocol {
    func makeClientID() -> String { "6f2c1e4a-0000-4000-8000-000000000001" }
    func unitInterval() -> Double { 0 }
}

struct HostAuthClock: NovaAuthClockProtocol {
    var value: () -> TimeInterval = { 100 }
    func now() throws -> NovaAuthTime { NovaAuthTime(bootID: "host-test-boot", continuousSeconds: value()) }
}

final class HostAuthProvider: NovaAuthProvidingProtocol {
    let client: NovaAuth
    let context: NovaAuthContext
    var failure: Error?

    init(client: NovaAuth, origin: String = "https://bittensor.test") throws {
        self.client = client
        context = try client.activate(origin: NovaAuthOrigin(origin))
    }

    var endpointAvailability: NovaAuthEndpointAvailability { NovaAuthEndpointAvailability() }

    func createEndpointWrapper() -> CompoundOperationWrapper<NovaAuthEndpoint> {
        if let failure { return .createWithError(failure) }
        return .createWithResult(NovaAuthEndpoint(context: context, client: client, invalidationRevision: 0))
    }

    func addContextObserver(_: AnyObject, closure _: @escaping () -> Void) {}

    func addAvailabilityObserver(
        _: AnyObject,
        closure _: @escaping (NovaAuthEndpointAvailability) -> Void
    ) -> NovaAuthEndpointAvailability { endpointAvailability }
}

final class HostAuthHarness {
    let client: NovaAuth
    let apple: HostAuthApple
    let identity: HostAuthIdentityStore
    let tokens: HostAuthTokenStore

    init(
        protocolClass: AnyClass,
        clock: HostAuthClock = HostAuthClock(),
        identity: HostAuthIdentityStore = HostAuthIdentityStore(),
        tokens: HostAuthTokenStore = HostAuthTokenStore()
    ) throws {
        let apple = HostAuthApple()
        let http = NovaAuthHTTPTransport(protocolClasses: [protocolClass])
        let owner = OperationQueue()
        owner.maxConcurrentOperationCount = 1
        self.apple = apple
        self.identity = identity
        self.tokens = tokens
        client = NovaAuth(dependencies: NovaAuthDependencies(
            appAttest: apple, identityStore: identity, tokenStore: tokens,
            clock: clock, random: HostAuthRandom(),
            bootstrap: NovaAuthBootstrapOperationFactory(http: http, clock: clock), http: http,
            ownerQueue: owner, bootstrapQueue: OperationQueue(), requestQueue: OperationQueue(),
            appIdentity: try NovaAuthAppIdentity(appID: "PREFIX.io.novafoundation.novawallet", environment: .development),
            logger: nil
        ))
    }
}

final class HostAuthAdmissionRecorder: NovaAuthClientProtocol {
    private let client: NovaAuthClientProtocol
    private let lock = NSLock()
    private var recordedContexts: [NovaAuthContext] = []
    private var recordedIntents: [NovaAuthRequestIntent] = []

    init(client: NovaAuthClientProtocol) { self.client = client }

    var isSupported: Bool { client.isSupported }
    var contexts: [NovaAuthContext] { lock.lock(); defer { lock.unlock() }; return recordedContexts }
    var intents: [NovaAuthRequestIntent] { lock.lock(); defer { lock.unlock() }; return recordedIntents }

    func createAdmissionWrapper(in context: NovaAuthContext, intent: NovaAuthRequestIntent) -> CompoundOperationWrapper<Void> {
        lock.lock()
        recordedContexts.append(context)
        recordedIntents.append(intent)
        lock.unlock()
        return client.createAdmissionWrapper(in: context, intent: intent)
    }

    func createResponseWrapper(
        for request: NovaAuthRequest,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        client.createResponseWrapper(for: request, beforeSend: beforeSend)
    }
}

final class HostConsentRecoveryQueue: OperationQueue, @unchecked Sendable {
    private let completions = DispatchGroup()

    override func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool) {
        for operation in ops {
            completions.enter()
            let completion = operation.completionBlock
            operation.completionBlock = { [completions] in
                completion?()
                completions.leave()
            }
        }
        super.addOperations(ops, waitUntilFinished: wait)
    }

    func drain(file: StaticString = #filePath, line: UInt = #line) {
        let completed = XCTestExpectation(description: "consent operation callbacks completed")
        completions.notify(queue: .global()) { completed.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 5), .completed, file: file, line: line)
    }
}

final class HostConsentRecoveryScheduler: AnalyticsConsentRecoveryScheduling {
    private let lock = NSLock()
    private var recordedDelays: [TimeInterval] = []

    var delays: [TimeInterval] { lock.lock(); defer { lock.unlock() }; return recordedDelays }

    func schedule(after delay: TimeInterval, action _: @escaping () -> Void) -> () -> Void {
        lock.lock()
        recordedDelays.append(delay)
        lock.unlock()
        return {}
    }
}

final class HostConsentRecoveryHarness {
    let client: HostAuthAdmissionRecorder
    let facade: NovaAuthFacade
    let queue = HostConsentRecoveryQueue()
    let scheduler = HostConsentRecoveryScheduler()
    let recovery: AnalyticsConsentAuthRecovery

    init(
        config: GlobalConfigProviding,
        auth: HostAuthHarness,
        isConsentEnabled: @escaping () -> Bool = { true }
    ) {
        client = HostAuthAdmissionRecorder(client: auth.client)
        facade = NovaAuthFacade(
            configProvider: config,
            client: client,
            contextInvalidationID: { auth.client.contextInvalidationID },
            activate: { try auth.client.activate(origin: $0) }
        )
        recovery = AnalyticsConsentAuthRecovery(
            provider: AnalyticsAuthAdapter(provider: facade),
            operationQueue: queue,
            scheduler: scheduler,
            isConsentEnabled: isConsentEnabled
        )
        recovery.setActive(true)
    }
}

import XCTest
import Operation_iOS
@testable import NovaAnalytics
@testable import NovaAuth
@testable import novawallet

final class AuthConfigProvider: GlobalConfigProviding {
    var snapshot: GlobalConfigSnapshot
    var requests = 0
    var resolve: (() throws -> GlobalConfigSnapshot)?
    private var callback: ((GlobalConfigSnapshot) -> Void)?

    init(origin: String = "https://first.test", revision: UInt64 = 1) {
        snapshot = Self.makeSnapshot(origin: origin, revision: revision)
    }

    static func makeSnapshot(origin: String, revision: UInt64) -> GlobalConfigSnapshot {
        let url = URL(string: origin)!
        return GlobalConfigSnapshot(config: GlobalConfig(multiStakingApiUrl: url, multisigsApiUrl: url, proxyApiUrl: url, infraUrl: url), revision: revision)
    }

    func publish(origin: String, revision: UInt64) {
        snapshot = Self.makeSnapshot(origin: origin, revision: revision)
        callback?(snapshot)
    }

    func addSnapshotObserver(_: AnyObject, closure: @escaping (GlobalConfigSnapshot) -> Void) { callback = closure }
    func createConfigSnapshotWrapper() -> CompoundOperationWrapper<GlobalConfigSnapshot> {
        requests += 1
        if let resolve { return CompoundOperationWrapper(targetOperation: ClosureOperation(closure: resolve)) }
        return .createWithResult(snapshot)
    }

    func createConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> { .createWithResult(snapshot.config) }
}

final class NovaAuthFacadeTests: XCTestCase {
    override func setUp() { super.setUp(); HostAuthURLProtocol.reset() }

    func testBuildMetadataScopesSharedAuthStoreToHostApp() throws {
        let namespace = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "NovaAuthHostAppNamespace") as? String)
        XCTAssertEqual(namespace, Bundle.main.bundleIdentifier)
        let configuration = try NovaAuthSharedStoreConfiguration(
            accessGroup: SharedContainerGroup.name,
            hostAppNamespace: namespace
        )
        XCTAssertEqual(configuration.hostAppNamespace, namespace)
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let completed = expectation(description: "facade operation completed")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: 10)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func facade(_ config: AuthConfigProvider, harness: HostAuthHarness) -> NovaAuthFacade {
        NovaAuthFacade(
            configProvider: config,
            client: harness.client,
            contextInvalidationID: { harness.client.contextInvalidationID },
            activate: { try harness.client.activate(origin: $0) }
        )
    }

    func testInvalidBaseURLsFailBeforeActivationOrBootstrap() throws {
        let invalidBaseURLs = [
            "https://example.test/path", "https://example.test//", "https://example.test/%2F",
            "https://example.test/./", "https://example.test/../",
            "https://example.test/?query=value", "https://example.test/?",
            "https://example.test/#fragment", "https://example.test/#",
            "https://user@example.test/", "https://user:password@example.test/",
            "https://@example.test/", "https://:password@example.test/",
            "http://example.test/", "HTTPS://example.test/", "https://EXAMPLE.test/",
            "https://example.test:443/", "https://example.test:08443/",
            "https://127.0.0.1/", "https://example.test./"
        ]

        for baseURL in invalidBaseURLs {
            let config = AuthConfigProvider(origin: baseURL)
            XCTAssertEqual(config.snapshot.config.infraUrl.absoluteString, baseURL)
            let harness = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
            let provider = facade(config, harness: harness)
            XCTAssertThrowsError(try run(provider.createEndpointWrapper()), baseURL) { error in
                XCTAssertEqual(error as? NovaAuthError, .invalidConfiguration, baseURL)
            }
            XCTAssertNil(harness.client.state?.context, baseURL)
            XCTAssertNil(harness.identity.state, baseURL)
            XCTAssertNil(try harness.tokens.load(), baseURL)
            XCTAssertEqual(harness.apple.attestations, 0, baseURL)
            XCTAssertEqual(harness.apple.assertions, 0, baseURL)
            XCTAssertTrue(HostAuthURLProtocol.requests.isEmpty, baseURL)
        }
    }

    func testNondefaultPortRootURLPreservesPort() throws {
        let config = AuthConfigProvider(origin: "https://example.test:8443/")
        let harness = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let endpoint = try run(facade(config, harness: harness).createEndpointWrapper())
        XCTAssertEqual(endpoint.context.origin.value, "https://example.test:8443")
    }

    func testUnsupportedGateNeverResolvesConfig() throws {
        let config = AuthConfigProvider()
        let harness = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        harness.apple.isSupported = false
        XCTAssertThrowsError(try run(facade(config, harness: harness).createEndpointWrapper()))
        XCTAssertEqual(config.requests, 0)
    }

    func testNewOriginPublicationFencesAlreadyCreatedRequestAndLateOldEndpoint() throws {
        let config = AuthConfigProvider()
        let harness = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let provider = facade(config, harness: harness)
        let first = try run(provider.createEndpointWrapper())
        let delayedOld = provider.createEndpointWrapper()
        let oldRequest = try NovaAuthRequest(
            context: first.context,
            method: .get,
            path: "/v1/bittensor/profile-3/subnets",
            queryItems: [],
            body: nil,
            contentType: nil,
            intent: .userInitiated
        )
        let waiting = first.client.createResponseWrapper(for: oldRequest, beforeSend: {})
        var invalidations = 0
        provider.addContextObserver(self) { invalidations += 1 }
        config.publish(origin: "https://second.test", revision: 2)
        XCTAssertEqual(harness.client.state?.context.origin.value, "https://second.test")
        XCTAssertEqual(try run(delayedOld).context.origin.value, "https://second.test")
        XCTAssertThrowsError(try run(waiting))
        XCTAssertTrue(HostAuthURLProtocol.requests.isEmpty)
        XCTAssertEqual(invalidations, 1)
    }

    func testAuthQueuesDoNotShareTheBusinessQueue() {
        XCTAssertEqual(OperationManagerFacade.novaAuthOwnerQueue.maxConcurrentOperationCount, 1)
        XCTAssertGreaterThanOrEqual(OperationManagerFacade.novaAuthBootstrapQueue.maxConcurrentOperationCount, 2)
        XCTAssertFalse(OperationManagerFacade.novaAuthOwnerQueue === OperationManagerFacade.novaAuthRequestQueue)
        XCTAssertFalse(OperationManagerFacade.novaAuthBootstrapQueue === OperationManagerFacade.novaAuthRequestQueue)
    }

    func testUnresolvedConsentParksUntilAdoptionAndWithdrawalDiscardsIt() throws {
        let auth = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let config = AuthConfigProvider()
        config.resolve = { throw URLError(.notConnectedToInternet) }
        var enabled = true
        let harness = HostConsentRecoveryHarness(config: config, auth: auth, isConsentEnabled: { enabled })

        harness.recovery.enableConsent()
        harness.queue.drain()
        XCTAssertEqual(config.requests, 1)
        XCTAssertTrue(harness.client.contexts.isEmpty)
        XCTAssertTrue(harness.scheduler.delays.isEmpty)

        config.publish(origin: "https://first.test", revision: 2)
        harness.queue.drain()
        XCTAssertEqual(config.requests, 1)
        XCTAssertEqual(harness.client.intents, [.userInitiated])
        XCTAssertNotNil(try auth.tokens.load())

        harness.recovery.cancel()
        harness.recovery.enableConsent()
        harness.queue.drain()
        XCTAssertEqual(harness.client.contexts.count, 1)
        enabled = false
        harness.recovery.cancel()
        config.publish(origin: "https://first.test", revision: 3)
        harness.queue.drain()
        XCTAssertEqual(harness.client.contexts.count, 1)

        config.resolve = nil
        enabled = true
        harness.recovery.enableConsent()
        harness.queue.drain()
        config.publish(origin: "https://first.test", revision: 4)
        harness.queue.drain()
        XCTAssertEqual(config.requests, 3)
        XCTAssertEqual(harness.client.intents, [.userInitiated, .userInitiated])
        XCTAssertTrue(harness.scheduler.delays.isEmpty)
        XCTAssertEqual(auth.apple.attestations, 1)
    }

    func testAvailabilityBeforeResolutionFailureWakesOnceButOlderReadinessCannot() throws {
        let auth = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let config = AuthConfigProvider()
        let harness = HostConsentRecoveryHarness(config: config, auth: auth)
        config.publish(origin: "https://first.test", revision: 1)
        config.resolve = { throw URLError(.notConnectedToInternet) }

        harness.recovery.enableConsent()
        harness.queue.drain()
        XCTAssertTrue(harness.client.contexts.isEmpty)
        XCTAssertTrue(harness.scheduler.delays.isEmpty)

        harness.recovery.cancel()
        config.resolve = { [weak config] in
            config?.publish(origin: "https://first.test", revision: 2)
            throw URLError(.notConnectedToInternet)
        }
        harness.recovery.enableConsent()
        harness.queue.drain()
        XCTAssertEqual(config.requests, 2)
        XCTAssertEqual(harness.client.intents, [.userInitiated])
        XCTAssertTrue(harness.scheduler.delays.isEmpty)

        config.publish(origin: "https://first.test", revision: 3)
        harness.queue.drain()
        XCTAssertEqual(config.requests, 2)
        XCTAssertEqual(harness.client.contexts.count, 1)
        XCTAssertEqual(auth.apple.attestations, 1)
    }

    func testColdOriginReplacementInvalidatesBeforeReadinessWithoutHoldingFacadeLock() throws {
        let previous = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let context = try previous.client.activate(origin: NovaAuthOrigin("https://old.test"))
        let auth = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self, identity: previous.identity)
        XCTAssertNil(auth.client.state?.context)
        let config = AuthConfigProvider()
        let harness = HostConsentRecoveryHarness(config: config, auth: auth)
        let readFromCallback = expectation(description: "facade state can be read during invalidation")
        let delivered = expectation(description: "newer readiness and delayed original readiness delivered")
        delivered.expectedFulfillmentCount = 2
        var invalidated = false
        harness.facade.addContextObserver(self) { [weak facade = harness.facade] in
            invalidated = true
            DispatchQueue.global().async {
                XCTAssertEqual(facade?.endpointAvailability.invalidationRevision, 1)
                config.publish(origin: "https://first.test", revision: 2)
                readFromCallback.fulfill()
            }
            XCTAssertEqual(XCTWaiter.wait(for: [readFromCallback], timeout: 2), .completed)
        }
        _ = harness.facade.addAvailabilityObserver(self) { availability in
            XCTAssertTrue(invalidated)
            XCTAssertEqual(availability.invalidationRevision, 1)
            delivered.fulfill()
        }

        harness.recovery.enableConsent()
        wait(for: [delivered], timeout: 5)
        harness.queue.drain()

        XCTAssertTrue(invalidated)
        XCTAssertEqual(auth.client.state?.context.origin.value, "https://first.test")
        XCTAssertEqual(auth.client.state?.context.generation, context.generation + 1)
        XCTAssertEqual(auth.identity.state?.context, auth.client.state?.context)
        XCTAssertEqual(config.requests, 1)
        XCTAssertTrue(harness.client.contexts.isEmpty)
        XCTAssertTrue(harness.scheduler.delays.isEmpty)
        XCTAssertTrue(HostAuthURLProtocol.requests.isEmpty)
        XCTAssertEqual(harness.facade.endpointAvailability.revision, 2)
    }

    func testColdReplacementPersistenceFailureDiscardsPendingConsentThroughAdapter() throws {
        let previous = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let context = try previous.client.activate(origin: NovaAuthOrigin("https://old.test"))
        previous.identity.saveError = NovaAuthError.storageUnavailable
        let auth = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self, identity: previous.identity)
        XCTAssertNil(auth.client.state?.context)
        let config = AuthConfigProvider()
        let harness = HostConsentRecoveryHarness(config: config, auth: auth)

        harness.recovery.enableConsent()
        harness.queue.drain()

        XCTAssertEqual(auth.client.state?.context.origin.value, "https://first.test")
        XCTAssertEqual(auth.client.state?.context.generation, context.generation + 1)
        XCTAssertEqual(auth.identity.state?.context, context)
        XCTAssertTrue(auth.client.storageFailed)
        XCTAssertEqual(harness.facade.endpointAvailability.invalidationRevision, 1)
        XCTAssertNil(harness.facade.endpointAvailability.endpoint)
        XCTAssertEqual(config.requests, 1)
        XCTAssertTrue(harness.client.contexts.isEmpty)
        XCTAssertTrue(harness.scheduler.delays.isEmpty)
        XCTAssertTrue(HostAuthURLProtocol.requests.isEmpty)

        auth.identity.saveError = nil
        config.publish(origin: "https://first.test", revision: 2)
        harness.queue.drain()
        XCTAssertNotNil(harness.facade.endpointAvailability.endpoint)
        XCTAssertTrue(harness.client.contexts.isEmpty)
        XCTAssertTrue(HostAuthURLProtocol.requests.isEmpty)
    }

    func testColdUnchangedOriginAdmitsPendingConsentThroughAdapterOnce() throws {
        let previous = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let context = try previous.client.activate(origin: NovaAuthOrigin("https://first.test"))
        let auth = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self, identity: previous.identity)
        XCTAssertNil(auth.client.state?.context)
        let config = AuthConfigProvider()
        let harness = HostConsentRecoveryHarness(config: config, auth: auth)

        harness.recovery.enableConsent()
        harness.queue.drain()
        config.publish(origin: "https://first.test", revision: 2)
        harness.queue.drain()

        XCTAssertEqual(auth.client.state?.context, context)
        XCTAssertEqual(config.requests, 1)
        XCTAssertEqual(harness.client.contexts, [context])
        XCTAssertEqual(harness.client.intents, [.userInitiated])
        XCTAssertTrue(harness.scheduler.delays.isEmpty)
        XCTAssertNotNil(try auth.tokens.load())
        XCTAssertEqual(auth.apple.attestations, 1)
        XCTAssertEqual(auth.apple.assertions, 1)
    }
}

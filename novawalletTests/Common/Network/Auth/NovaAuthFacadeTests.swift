import XCTest
import Operation_iOS
import NovaAnalytics
@testable import NovaAuth
@testable import novawallet

final class AuthConfigProvider: GlobalConfigProviding {
    var snapshot: GlobalConfigSnapshot
    var requests = 0
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
        return .createWithResult(snapshot)
    }

    func createConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> { .createWithResult(snapshot.config) }
    func createFreshConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> { createConfigWrapper() }
}

final class NovaAuthFacadeTests: XCTestCase {
    override func setUp() { super.setUp(); HostAuthURLProtocol.reset() }

    func testBuildMetadataScopesSharedAuthStoreToHostApp() throws {
        let namespace = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "NovaAuthHostAppNamespace") as? String)
        XCTAssertEqual(namespace, Bundle.main.bundleIdentifier)
        let configuration = try NovaAuthSharedStoreConfiguration(
            accessGroup: SharedContainerGroup.name,
            containerURL: FileManager.default.temporaryDirectory,
            hostAppNamespace: namespace
        )
        XCTAssertEqual(configuration.hostAppNamespace, namespace)
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func facade(_ config: AuthConfigProvider, harness: HostAuthHarness, unitTesting: Bool = false) -> NovaAuthFacade {
        NovaAuthFacade(
            configProvider: config,
            client: harness.client,
            isUnitTesting: unitTesting,
            activate: { try harness.client.activate(origin: $0) },
            reset: { try harness.client.reset() }
        )
    }

    func testAnalyticsAndBittensorHaveExactlyTheSameClient() throws {
        let harness = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let provider = facade(AuthConfigProvider(), harness: harness)
        let analytics = try run(AnalyticsAuthAdapter(provider: provider).createAuthWrapper())
        let bittensor = BittensorAuthorizedTransport(provider: provider, operationQueue: OperationQueue())
        let admission = try run(bittensor.createAdmissionWrapper(intent: .userInitiated))
        XCTAssertTrue(analytics.client === admission.endpoint?.client)
        XCTAssertTrue(analytics.client === harness.client)
    }

    func testUnitTestingGateNeverResolvesConfigOrBootstraps() throws {
        let config = AuthConfigProvider()
        let harness = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let provider = facade(config, harness: harness, unitTesting: true)
        XCTAssertThrowsError(try run(provider.createEndpointWrapper()))
        XCTAssertEqual(config.requests, 0)
        XCTAssertTrue(HostAuthURLProtocol.requests.isEmpty)
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
        XCTAssertEqual(harness.client.currentContext?.origin.value, "https://second.test")
        XCTAssertEqual(try run(delayedOld).context.origin.value, "https://second.test")
        XCTAssertThrowsError(try run(waiting))
        XCTAssertTrue(HostAuthURLProtocol.requests.isEmpty)
        XCTAssertEqual(invalidations, 1)
    }

    func testExplicitResetRequiresUserDemandAndNeverAcceptsAnOlderOrigin() throws {
        let config = AuthConfigProvider()
        let harness = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let provider = facade(config, harness: harness)
        _ = try run(provider.createEndpointWrapper())
        let old = provider.createEndpointWrapper()
        config.publish(origin: "https://second.test", revision: 2)
        try provider.reset()
        let endpoint = try run(old)
        XCTAssertEqual(endpoint.context.origin.value, "https://second.test")
        XCTAssertThrowsError(try run(endpoint.client.createAdmissionWrapper(in: endpoint.context, intent: .background)))
        XCTAssertTrue(HostAuthURLProtocol.requests.isEmpty)
        try run(endpoint.client.createAdmissionWrapper(in: endpoint.context, intent: .userInitiated))
        XCTAssertEqual(harness.apple.assertions, 1)
    }

    func testAuthQueuesDoNotShareTheBusinessQueue() {
        XCTAssertEqual(OperationManagerFacade.novaAuthOwnerQueue.maxConcurrentOperationCount, 1)
        XCTAssertGreaterThanOrEqual(OperationManagerFacade.novaAuthBootstrapQueue.maxConcurrentOperationCount, 2)
        XCTAssertFalse(OperationManagerFacade.novaAuthOwnerQueue === OperationManagerFacade.novaAuthRequestQueue)
        XCTAssertFalse(OperationManagerFacade.novaAuthBootstrapQueue === OperationManagerFacade.novaAuthRequestQueue)
    }
}

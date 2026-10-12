import Foundation
import Operation_iOS
@testable import NovaAuth
@testable import novawallet

final class HostAuthIdentityStore: NovaAuthIdentityStoreProtocol {
    var state: NovaAuthInstallationState?
    func load() throws -> NovaAuthInstallationState? { state }
    func save(_ state: NovaAuthInstallationState) throws { self.state = state }
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
    func createKeyWrapper() -> CompoundOperationWrapper<String> { .createWithResult(Data(repeating: 1, count: 32).base64EncodedString()) }
    func createAttestationWrapper(keyID _: String, clientDataHash _: Data) -> CompoundOperationWrapper<Data> {
        attestations += 1
        return .createWithResult(Data([1, 2, 3]))
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

    func createEndpointWrapper() -> CompoundOperationWrapper<NovaAuthEndpoint> {
        if let failure { return .createWithError(failure) }
        return .createWithResult(NovaAuthEndpoint(context: context, client: client))
    }
}

final class HostAuthHarness {
    let client: NovaAuth
    let apple: HostAuthApple
    let identity: HostAuthIdentityStore
    let tokens: HostAuthTokenStore

    init(protocolClass: AnyClass, clock: HostAuthClock = HostAuthClock()) throws {
        let apple = HostAuthApple()
        let identity = HostAuthIdentityStore()
        let tokens = HostAuthTokenStore()
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

import Keystore_iOS
@testable import NovaAuth
import Operation_iOS
import XCTest

final class AuthHarness {
    let clock = TestClock()
    let apple = TestApple()
    let server = FakeAuthServer()
    let tokens = TestTokenStore()
    let settings = InMemorySettingsManager()
    let random = TestRandom()
    let ownerQueue = OperationQueue()
    let origin: NovaAuthOrigin
    private var appIdentity: NovaAuthAppIdentity

    init() throws {
        origin = try NovaAuthOrigin("https://auth.example.com")
        appIdentity = try NovaAuthAppIdentity(appID: "PREFIX.io.nova.wallet", environment: .development, version: "1")
        ownerQueue.maxConcurrentOperationCount = 1
    }

    func makeAuth() -> NovaAuth {
        NovaAuth(dependencies: NovaAuthDependencies(
            appAttest: apple, identityStore: NovaAuthSettingsIdentityStore(settingsManager: settings),
            tokenStore: tokens, clock: clock, random: random,
            http: server,
            ownerQueue: ownerQueue, bootstrapQueue: OperationQueue(), requestQueue: OperationQueue(),
            appIdentity: appIdentity, logger: nil
        ))
    }

    func relaunch(version: String? = nil) throws -> NovaAuth {
        if let version {
            appIdentity = try NovaAuthAppIdentity(
                appID: appIdentity.appID, environment: appIdentity.environment, version: version
            )
        }
        let auth = makeAuth()
        _ = try auth.activate(origin: origin)
        return auth
    }

    func request(_ context: NovaAuthContext, analytics: Bool = false) throws -> NovaAuthRequest {
        try NovaAuthRequest(
            context: context,
            method: analytics ? .post : .get,
            path: analytics ? "/v1/analytics/events" : "/v1/bittensor/subnets",
            queryItems: [],
            body: analytics ? Data("{}".utf8) : nil,
            contentType: analytics ? "application/json" : nil,
            intent: analytics ? .background : .userDriven
        )
    }
}

extension XCTestCase {
    @discardableResult
    func execute<Value>(_ wrapper: CompoundOperationWrapper<Value>) throws -> Value {
        let completed = expectation(description: "operation completed")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: 5)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func assertError<Value>(
        _ expected: NovaAuthError,
        _ wrapper: CompoundOperationWrapper<Value>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try execute(wrapper), file: file, line: line) {
            XCTAssertEqual($0 as? NovaAuthError, expected, file: file, line: line)
        }
    }

    func registered(_ harness: AuthHarness) throws -> (NovaAuth, NovaAuthContext) {
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        try execute(auth.createAdmissionWrapper(in: context))
        return (auth, context)
    }
}

final class TestClock: NovaAuthClockProtocol {
    private let lock = NSLock()
    private var seconds: TimeInterval = 100
    func now() throws -> NovaAuthTime {
        lock.novaAuthLocked { NovaAuthTime(bootID: "boot", continuousSeconds: seconds) }
    }

    func advance(_ delta: TimeInterval) {
        lock.novaAuthLocked { seconds += delta }
    }
}

final class TestRandom: NovaAuthRandomProtocol {
    private(set) var clientIDs = 0

    func makeClientID() -> String {
        clientIDs += 1
        return "11111111-1111-4111-8111-" + String(format: "%012d", clientIDs)
    }

    func unitInterval() -> Double {
        0
    }
}

final class TestApple: NovaAuthAppAttestProtocol {
    let isSupported = true
    var attestationError: Error?
    var lostKeyIDs: Set<String> = []
    private(set) var keys = 0
    private(set) var attestations = 0

    func isBusy(keyID _: String) -> Bool {
        false
    }

    func createKeyWrapper() -> CompoundOperationWrapper<String> {
        keys += 1
        return .createWithResult(Data(repeating: UInt8(keys), count: 32).base64EncodedString())
    }

    func createAttestationWrapper(keyID _: String, clientDataHash _: Data, beforeAttest: @escaping () throws -> Void)
        -> CompoundOperationWrapper<Data> {
        attestations += 1
        if let attestationError { return .createWithError(attestationError) }
        return CompoundOperationWrapper(targetOperation: ClosureOperation { try beforeAttest(); return Data([1]) })
    }

    func createAssertionWrapper(keyID: String, clientDataHash _: Data) -> CompoundOperationWrapper<Data> {
        if lostKeyIDs.contains(keyID) { return .createWithError(NovaAuthAppAttestError.invalidKey) }
        return .createWithResult(Data([2]))
    }
}

final class TestTokenStore: NovaAuthTokenStoreProtocol {
    private let lock = NSLock()
    private var record: NovaAuthTokenRecord?
    var onReplace: (() -> Void)?

    func load() throws -> NovaAuthTokenRecord? {
        lock.novaAuthLocked { record }
    }

    func replace(_ record: NovaAuthTokenRecord) throws {
        lock.novaAuthLocked { self.record = record }; onReplace?()
    }

    func removeAll() throws {
        lock.novaAuthLocked { record = nil }
    }

    func remove(ifMatching record: NovaAuthTokenRecord) throws -> Bool {
        lock.novaAuthLocked {
            guard self.record == record else { return false }
            self.record = nil
            return true
        }
    }
}

final class FakeAuthServer: NovaAuthHTTPProtocol {
    struct Reply {
        var status = 200
        var headers: [String: String] = [:]
        var body = Data()
    }

    private let lock = NSLock()
    private var sent: [URLRequest] = []
    var registration: Result<Reply, Error> = .success(Reply(status: 204))
    var business: (URLRequest) -> Reply = { _ in Reply(body: Data("{}".utf8)) }
    var token: Reply?
    var beforeToken: (() -> Void)?

    var requests: [URLRequest] {
        lock.novaAuthLocked { sent }
    }

    var businessRequests: [URLRequest] {
        requests.filter { $0.url?.path.contains("/attestation/") == false }
    }

    func count(_ suffix: String) -> Int {
        requests.filter { $0.url?.path.hasSuffix(suffix) == true }.count
    }

    func createResponseWrapper(for request: URLRequest, kind _: NovaAuthHTTPKind, beforeSend: @escaping () throws -> Void)
        -> CompoundOperationWrapper<NovaAuthResponse> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { [self] in
            try beforeSend()
            lock.novaAuthLocked { sent.append(request) }
            let reply = try reply(for: request)
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers
            ))
            return NovaAuthResponse(response: response, body: reply.body)
        })
    }

    static func error(_ code: String) -> Data {
        Data(#"{"error":{"code":"\#(code)","message":"refused"}}"#.utf8)
    }
}

private extension FakeAuthServer {
    func reply(for request: URLRequest) throws -> Reply {
        switch request.url?.path {
        case "/v1/attestation/profile-3/challenges", "/v1/attestation/profile-3/token-challenges":
            return Reply(body: Data(
                #"{"challenge":"AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8","issued_at":1000,"expires_at":1060}"#.utf8
            ))
        case "/v1/attestation/profile-3/register":
            return try registration.get()
        case "/v1/attestation/profile-3/tokens":
            beforeToken?()
            if let token { return token }
            let token = #"{"access_token":"bearer-\#(count("/tokens"))","token_type":"Bearer","issued_at":1000,"expires_at":1600}"#
            return Reply(body: Data(token.utf8))
        default:
            return business(request)
        }
    }
}

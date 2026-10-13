import XCTest
import Operation_iOS
@testable import NovaAuth

final class NovaAuthBootstrapTests: XCTestCase {
    func testFourExactBootstrapRequests() throws {
        let http = FoundationTestHTTP()
        let factory = NovaAuthBootstrapOperationFactory(http: http, clock: FoundationTestClock())
        let challenge = "{\"challenge\":\"\(FoundationFixture.challenge)\",\"issued_at\":100,\"expires_at\":160}"
        let origin = try FoundationFixture.origin()
        http.response = try FoundationFixture.response(challenge, path: "/v1/attestation/profile-3/challenges")
        _ = try executeFoundation(
            factory
                .createRegistrationChallengeWrapper(origin: origin, clientID: FoundationFixture.clientID, beforeSend: {})
        )
        try check(
            http.requests[0],
            path: "/v1/attestation/profile-3/challenges",
            keys: ["profile", "client_id", "purpose"]
        )
        XCTAssertEqual(try object(http.requests[0])["purpose"] as? String, "register")

        http.response = try FoundationFixture.response("", status: 204, path: "/v1/attestation/profile-3/register")
        let register = NovaAuthRegistrationRequest(
            origin: origin,
            clientID: FoundationFixture.clientID,
            challenge: FoundationFixture.challenge,
            appIdentity: try FoundationFixture.identity(),
            keyID: FoundationFixture.keyID,
            attestation: Data([1, 2, 3]),
            contentType: "application/json; charset=utf-8"
        )
        try executeFoundation(factory.createRegistrationWrapper(register, beforeSend: {}))
        try check(
            http.requests[1],
            path: "/v1/attestation/profile-3/register",
            keys: ["profile", "client_id", "challenge", "platform", "app_id", "attestation_type",
                   "key_reference", "app_attest_environment", "integrity_token"]
        )
        XCTAssertEqual(
            try object(http.requests[1])["integrity_token"] as? String,
            Data([1, 2, 3]).base64EncodedString()
        )
        XCTAssertEqual(http.requests[1].timeoutInterval, 100)
        XCTAssertEqual(http.requests[1].value(forHTTPHeaderField: "Content-Type"), register.contentType)

        http.response = try FoundationFixture.response(challenge, path: "/v1/attestation/profile-3/token-challenges")
        _ = try executeFoundation(
            factory
                .createTokenChallengeWrapper(origin: origin, clientID: FoundationFixture.clientID, beforeSend: {})
        )
        try check(
            http.requests[2],
            path: "/v1/attestation/profile-3/token-challenges",
            keys: ["profile", "client_id", "purpose"]
        )
        XCTAssertEqual(try object(http.requests[2])["purpose"] as? String, "token")

        http.response = try FoundationFixture
            .response("{\"access_token\":\"synthetic\",\"token_type\":\"Bearer\",\"issued_at\":100,\"expires_at\":400}")
        let token = NovaAuthTokenRequest(
            origin: origin,
            clientID: FoundationFixture.clientID,
            challenge: FoundationFixture.challenge,
            assertion: Data([4, 5]),
            contentType: "application/json"
        )
        _ = try executeFoundation(factory.createTokenWrapper(token, beforeSend: {}))
        try check(
            http.requests[3],
            path: "/v1/attestation/profile-3/tokens",
            keys: ["profile", "client_id", "challenge", "app_attest_assertion"]
        )
        XCTAssertEqual(http.requests[3].timeoutInterval, 20)
        XCTAssertEqual(http.kinds.count, 4)
    }

    func testActualSendFencePreventsQueuedBootstrap() throws {
        let http = FoundationTestHTTP()
        let factory = NovaAuthBootstrapOperationFactory(http: http, clock: FoundationTestClock())
        let wrapper = factory.createTokenChallengeWrapper(
            origin: try FoundationFixture.origin(),
            clientID: FoundationFixture.clientID,
            beforeSend: { throw NovaAuthError.generationChanged }
        )
        XCTAssertThrowsError(try executeFoundation(wrapper)) { XCTAssertEqual($0 as? NovaAuthError, .generationChanged)
        }
        XCTAssertTrue(http.requests.isEmpty)
    }

    func testOversizedProofsFailBeforeHTTP() throws {
        let origin = try FoundationFixture.origin()
        let token = NovaAuthTokenRequest(
            origin: origin,
            clientID: FoundationFixture.clientID,
            challenge: FoundationFixture.challenge,
            assertion: Data(repeating: 0, count: 6145),
            contentType: "application/json"
        )
        XCTAssertThrowsError(try NovaAuthWire.tokenBody(token))
        let register = NovaAuthRegistrationRequest(
            origin: origin,
            clientID: FoundationFixture.clientID,
            challenge: FoundationFixture.challenge,
            appIdentity: try FoundationFixture.identity(),
            keyID: FoundationFixture.keyID,
            attestation: Data(repeating: 0, count: 49153),
            contentType: "application/json"
        )
        XCTAssertThrowsError(try NovaAuthWire.registrationBody(register))
    }

    private func check(_ request: URLRequest, path: String, keys: Set<String>) throws {
        XCTAssertEqual(request.url?.absoluteString, "https://example.com" + path)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Length"),
            String(try XCTUnwrap(request.httpBody).count)
        )
        XCTAssertEqual(Set(try object(request).keys), keys)
        XCTAssertEqual(try object(request)["profile"] as? Int, 3)
        XCTAssertEqual(
            Set((request.allHTTPHeaderFields ?? [:]).keys.map { $0.lowercased() }),
            ["content-length", "content-type"]
        )
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    private func object(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    }
}

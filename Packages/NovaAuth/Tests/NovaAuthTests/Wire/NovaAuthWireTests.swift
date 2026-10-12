import XCTest
@testable import NovaAuth

final class NovaAuthWireTests: XCTestCase {
    func testStrictChallengeDecoding() throws {
        let value = try NovaAuthWire.decodeChallenge(FoundationFixture.response(challengeJSON(issued: "100", expires: "160")))
        XCTAssertEqual(value.issuedAt, 100)
        for invalid in ["true", "\"100\"", "100.0", "1e2", "-1", "9223372036854775808", "NaN", "Infinity", "0100", "+100"] {
            XCTAssertThrowsError(try NovaAuthWire.decodeChallenge(FoundationFixture.response(challengeJSON(issued: invalid, expires: "160"))))
        }
        for expires in ["159", "161", "-1", "9223372036854775807"] {
            XCTAssertThrowsError(try NovaAuthWire.decodeChallenge(FoundationFixture.response(challengeJSON(issued: "100", expires: expires))))
        }
        let atMaximum = challengeJSON(issued: "9223372036854775747", expires: "9223372036854775807")
        XCTAssertNoThrow(try NovaAuthWire.decodeChallenge(FoundationFixture.response(atMaximum)))
    }

    func testStrictJSONRejectsBOMDuplicatesEscapedDuplicatesAndTrailingContent() throws {
        let valid = challengeJSON(issued: "0", expires: "60")
        let malformed = ["\u{FEFF}" + valid, valid + "{}", valid.replacingOccurrences(of: "\"issued_at\":0", with: "\"issued_at\":0,\"issued_at\":0"),
                         valid.replacingOccurrences(of: "\"issued_at\":0", with: "\"issued_at\":0,\"issued_\\u0061t\":0"),
                         valid.replacingOccurrences(of: "}", with: ",\"extra\":null}"), "[" + valid + "]"]
        for json in malformed { XCTAssertThrowsError(try NovaAuthWire.decodeChallenge(FoundationFixture.response(json))) }
        XCTAssertThrowsError(try NovaAuthJSON.parse(Data([0x7B, 0xFF, 0x7D]), limit: 1024))
        XCTAssertThrowsError(try NovaAuthJSON.parse(Data("{\"a\":{\"b\":{\"c\":{\"d\":{}}}}}".utf8), limit: 1024))
        XCTAssertThrowsError(try NovaAuthJSON.parse(Data("{\"a\":\"\\uD800\"}".utf8), limit: 1024))
    }

    func testTokenIsOpaqueAndLifetimeBoundsAreStrict() throws {
        for lifetime in [60, 900] {
            let response = try NovaAuthWire.decodeToken(FoundationFixture.response(tokenJSON(expires: "\(100 + lifetime)")))
            XCTAssertEqual(response.expiresAt, Int64(100 + lifetime))
        }
        for expires in ["100", "159", "1001", "400.0", "4e2", "true", "\"400\""] {
            XCTAssertThrowsError(try NovaAuthWire.decodeToken(FoundationFixture.response(tokenJSON(expires: expires))))
        }
        for token in ["", "unsafe token", "unsafe,token", "unsafe\n", "é", String(repeating: "x", count: 3073)] {
            XCTAssertThrowsError(try NovaAuthValidation.token(token))
        }
        XCTAssertNoThrow(try NovaAuthValidation.token(String(repeating: "x", count: 3072)))
        XCTAssertThrowsError(try NovaAuthWire.decodeToken(FoundationFixture.response(tokenJSON().replacingOccurrences(of: "Bearer", with: "bearer"))))
        XCTAssertThrowsError(try NovaAuthWire.decodeToken(FoundationFixture.response(tokenJSON(), status: 201)))
        XCTAssertNoThrow(try NovaAuthWire.decodeRegistration(FoundationFixture.response("", status: 204)))
        XCTAssertThrowsError(try NovaAuthWire.decodeRegistration(FoundationFixture.response(" ", status: 204)))
        XCTAssertThrowsError(try NovaAuthWire.decodeRegistration(FoundationFixture.response("", status: 200)))
    }

    func testCanonicalEncodingsAndBounds() throws {
        XCTAssertNoThrow(try NovaAuthValidation.clientID(FoundationFixture.clientID))
        XCTAssertThrowsError(try NovaAuthValidation.clientID(FoundationFixture.clientID.uppercased()))
        XCTAssertThrowsError(try NovaAuthValidation.clientID("6f2c1e4a-0000-1000-8000-000000000001"))
        XCTAssertNoThrow(try NovaAuthValidation.keyID(FoundationFixture.keyID))
        XCTAssertThrowsError(try NovaAuthValidation.keyID(String(FoundationFixture.keyID.dropLast())))
        XCTAssertThrowsError(try NovaAuthValidation.keyID(FoundationFixture.keyID + "\n"))
        XCTAssertNoThrow(try NovaAuthValidation.challenge(FoundationFixture.challenge))
        XCTAssertThrowsError(try NovaAuthValidation.challenge(FoundationFixture.keyID))
        XCTAssertThrowsError(try NovaAuthValidation.challenge(String(FoundationFixture.challenge.dropLast()) + "9"))
    }

    func testErrorEnvelopePreservesUnknownCodesWithoutProviderPayload() throws {
        let body = "{\"error\":{\"code\":\"future_code\",\"message\":\"Safe\",\"future\":{\"bounded\":true}}}"
        let response = try FoundationFixture.response(body, status: 429, headers: ["X-Request-ID": "safe:request-id", "Retry-After": "9999"])
        let error = NovaAuthWire.serverError(response)
        XCTAssertEqual(error.code, "future_code")
        XCTAssertEqual(error.requestID, "safe:request-id")
        XCTAssertEqual(error.retryAfter, 905)
        XCTAssertNil(NovaAuthWire.errorCode(from: Data("{\"error\":{\"code\":\"invalid_token\"}}".utf8)))
        XCTAssertNil(NovaAuthWire.errorCode(from: Data(body.replacingOccurrences(of: "future_code", with: "Bad Code").utf8)))
        XCTAssertNil(NovaAuthWire.requestID(try FoundationFixture.response("", headers: ["X-Request-ID": "unsafe value"]).response))
        for value in ["-1", "1.0", "1e2", "Sun, 12 Oct", "", "100000000000000000000000"] {
            XCTAssertNil(NovaAuthWire.retryAfter(try FoundationFixture.response("", headers: ["Retry-After": value]).response))
        }
    }

    private func challengeJSON(issued: String, expires: String) -> String {
        "{\"challenge\":\"\(FoundationFixture.challenge)\",\"issued_at\":\(issued),\"expires_at\":\(expires)}"
    }

    private func tokenJSON(expires: String = "400") -> String {
        "{\"access_token\":\"opaque-without-claims\",\"token_type\":\"Bearer\",\"issued_at\":100,\"expires_at\":\(expires)}"
    }
}

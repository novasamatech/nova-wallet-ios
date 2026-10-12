import XCTest
@testable import NovaAuth

final class NovaAuthRequestTests: XCTestCase {
    func testOriginRejectsAliasesBeforeFoundationCanonicalization() throws {
        let invalid = ["http://example.com", "HTTPS://example.com", "https://EXAMPLE.com", "https://example.com/",
                       "https://example.com?", "https://example.com#", "https://user@example.com", "https://example.com:443",
                       "https://example.com:0443", "https://example.com:08443", "https://example.com:0", "https://example.com:65536",
                       "https://127.0.0.1", "https://[::1]", "https://example.com.", "https://-a.com", "https://a-.com",
                       "https://a..com", "https://é.com", "https://%65xample.com", "https://example.com\n", "https://example.com\\evil",
                       "https://" + String(repeating: "a", count: 64) + ".com"]
        for origin in invalid { XCTAssertThrowsError(try NovaAuthOrigin(origin)) }
        XCTAssertEqual(try NovaAuthOrigin("https://example.com:8443").url.port, 8443)
        XCTAssertThrowsError(try JSONDecoder().decode(NovaAuthOrigin.self, from: Data("\"https://EXAMPLE.com\"".utf8)))
        XCTAssertNoThrow(try NovaAuthAppIdentity(appID: "PREFIX.io.nova-wallet.app", environment: .development))
        for appID in ["", "nosplit", ".app", "prefix.", "prefix.io..wallet", "prefix.io_wallet", "prefix.é"] {
            XCTAssertThrowsError(try NovaAuthAppIdentity(appID: appID, environment: .production))
        }
    }

    func testAllSevenCanonicalReadsAndBothApprovedPosts() throws {
        let suffixes = ["subnets", "subnets/0/validators", "yields/root", "subnets/65535/yields/alpha", "recommendations",
                        "recommendations/subnets", "recommendations/subnets/1/validators"]
        for suffix in suffixes {
            for method in [NovaAuthMethod.get, .head] {
                let request = try make(method: method, path: "/v1/bittensor/profile-3/" + suffix)
                XCTAssertEqual(try request.makeURL().path, request.path)
            }
        }
        for path in ["/v1/analytics/events", "/v1/bittensor/operations/search"] {
            XCTAssertNoThrow(try make(method: .post, path: path, body: Data("{}".utf8), contentType: "application/json"))
        }
        let invalid = ["subnets/01/validators", "subnets/+1/validators", "subnets/65536/validators", "subnets//validators",
                       "subnets/1/validators/", "subnets/1/../validators", "subnets/%31/validators", "subnets/1/%76alidators"]
        for suffix in invalid { XCTAssertThrowsError(try make(path: "/v1/bittensor/profile-3/" + suffix)) }
        XCTAssertThrowsError(try make(path: "/v1/bittensor/subnets"))
        XCTAssertThrowsError(try make(path: "/v1/bittensor/profile-3/subnets", body: Data()))
        XCTAssertThrowsError(try make(method: .post, path: "/v1/bittensor/profile-3/subnets", body: Data(), contentType: "application/json"))
    }

    func testQueryCannotChangeOriginOrFragment() throws {
        let request = try NovaAuthRequest(
            context: FoundationFixture.context(),
            method: .get,
            path: "/v1/bittensor/profile-3/subnets",
            queryItems: [URLQueryItem(name: "q", value: "#https://evil.example/path")],
            body: nil,
            contentType: nil,
            intent: .userInitiated
        )
        let url = try request.makeURL()
        XCTAssertEqual(url.host, "example.com")
        XCTAssertNil(url.fragment)
    }

    private func make(
        method: NovaAuthMethod = .get,
        path: String,
        body: Data? = nil,
        contentType: String? = nil
    ) throws -> NovaAuthRequest {
        try NovaAuthRequest(
            context: FoundationFixture.context(),
            method: method,
            path: path,
            queryItems: [],
            body: body,
            contentType: contentType,
            intent: .userInitiated
        )
    }
}

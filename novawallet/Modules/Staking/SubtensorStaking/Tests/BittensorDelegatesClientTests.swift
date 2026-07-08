import XCTest
@testable import novawallet

final class BittensorDelegatesClientTests: XCTestCase {
    // MARK: - Happy path

    func test_parse_validJsonWithAllFields_extractsBothEntries() throws {
        let json = """
        {
          "5E2LP6EnZ54m3wS8s1yPvD5c3xo71kQroBw7aUVK32TKeZ5u": {
            "name": "tao.bot",
            "url": "https://tao.bot",
            "description": "Test validator",
            "signature": "deadbeef"
          },
          "5DXVbg1vRYTsJnc3nLKp3UNjpuGfpvvTdcGXNTcd8ukx95B2": {
            "name": "OPSEC",
            "url": "https://opsec.computer/",
            "description": "Test",
            "signature": "cafef00d"
          }
        }
        """.data(using: .utf8)!

        let delegates = try BittensorDelegatesClient.parse(jsonData: json)

        XCTAssertEqual(delegates.count, 2)
        XCTAssertEqual(delegates["5E2LP6EnZ54m3wS8s1yPvD5c3xo71kQroBw7aUVK32TKeZ5u"]?.name, "tao.bot")
        XCTAssertEqual(delegates["5E2LP6EnZ54m3wS8s1yPvD5c3xo71kQroBw7aUVK32TKeZ5u"]?.url, "https://tao.bot")
        XCTAssertEqual(delegates["5E2LP6EnZ54m3wS8s1yPvD5c3xo71kQroBw7aUVK32TKeZ5u"]?.description, "Test validator")
        XCTAssertEqual(delegates["5E2LP6EnZ54m3wS8s1yPvD5c3xo71kQroBw7aUVK32TKeZ5u"]?.signature, "deadbeef")
        XCTAssertEqual(delegates["5DXVbg1vRYTsJnc3nLKp3UNjpuGfpvvTdcGXNTcd8ukx95B2"]?.name, "OPSEC")
        XCTAssertEqual(delegates["5DXVbg1vRYTsJnc3nLKp3UNjpuGfpvvTdcGXNTcd8ukx95B2"]?.url, "https://opsec.computer/")
    }

    // MARK: - Optional field handling

    func test_parse_entryWithOnlyName_parsesWithNilOptionals() throws {
        let json = """
        {
          "5Example": {
            "name": "Anon"
          }
        }
        """.data(using: .utf8)!

        let delegates = try BittensorDelegatesClient.parse(jsonData: json)

        XCTAssertEqual(delegates.count, 1)
        XCTAssertEqual(delegates["5Example"]?.name, "Anon")
        XCTAssertNil(delegates["5Example"]?.url)
        XCTAssertNil(delegates["5Example"]?.description)
        XCTAssertNil(delegates["5Example"]?.signature)
    }

    // MARK: - Empty object

    func test_parse_emptyJsonObject_returnsEmptyDictionary() throws {
        let json = "{}".data(using: .utf8)!

        let delegates = try BittensorDelegatesClient.parse(jsonData: json)

        XCTAssertTrue(delegates.isEmpty)
    }

    // MARK: - Error cases

    func test_parse_malformedJson_throws() {
        let json = "{ not valid json".data(using: .utf8)!

        XCTAssertThrowsError(try BittensorDelegatesClient.parse(jsonData: json))
    }

    func test_parse_entryMissingRequiredName_throws() {
        // `name` is non-optional on BittensorDelegateMetadata, so this should throw
        let json = """
        {
          "5Example": {
            "url": "https://example.com"
          }
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try BittensorDelegatesClient.parse(jsonData: json))
    }

    // MARK: - Cache

    func test_cachedDelegates_returnsEmptyBeforeAnyFetch() async {
        let client = BittensorDelegatesClient()
        let cached = await client.cachedDelegates()
        XCTAssertTrue(cached.isEmpty)
    }
}

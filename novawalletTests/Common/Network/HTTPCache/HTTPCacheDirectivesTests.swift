@testable import novawallet
import XCTest

final class HTTPCacheDirectivesTests: XCTestCase {
    func testContractValueWithAgeIsReusableForMaxAgeMinusAge() throws {
        let response = try makeResponse(
            headerFields: ["Cache-Control": "private, max-age=300, must-revalidate", "Age": "20"]
        )

        XCTAssertEqual(HTTPCacheDirectives(response: response), .reusable(lifetime: 280))
    }

    func testNoStoreIsNotStorable() {
        XCTAssertEqual(HTTPCacheDirectives(cacheControl: "no-store", age: nil), .notStorable)
    }

    func testMissingCacheControlIsNotStorable() throws {
        let response = try makeResponse(headerFields: [:])

        XCTAssertEqual(HTTPCacheDirectives(response: response), .notStorable)
    }

    func testNoCacheBesideMaxAgeIsNotStorable() {
        XCTAssertEqual(HTTPCacheDirectives(cacheControl: "no-cache, max-age=300", age: nil), .notStorable)
    }

    func testSharedMaxAgeAloneIsNotStorable() {
        XCTAssertEqual(HTTPCacheDirectives(cacheControl: "s-maxage=600", age: nil), .notStorable)
    }

    func testRepeatedMaxAgeIsNotStorable() {
        XCTAssertEqual(HTTPCacheDirectives(cacheControl: "max-age=60, max-age=60", age: nil), .notStorable)
    }

    func testMixedCaseQuotedMaxAgeIsReusable() {
        XCTAssertEqual(
            HTTPCacheDirectives(cacheControl: "Private, MAX-AGE=\"60\"", age: nil),
            .reusable(lifetime: 60)
        )
    }

    func testAgeEqualToMaxAgeIsNotStorable() {
        XCTAssertEqual(
            HTTPCacheDirectives(cacheControl: "private, max-age=300, must-revalidate", age: "300"),
            .notStorable
        )
    }

    private func makeResponse(headerFields: [String: String]) throws -> HTTPURLResponse {
        let url = try XCTUnwrap(URL(string: "https://bittensor.test/v1/bittensor/subnets"))

        return try XCTUnwrap(
            HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headerFields)
        )
    }
}

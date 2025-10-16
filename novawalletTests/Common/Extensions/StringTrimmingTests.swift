import XCTest
@testable import novawallet

final class StringTrimmingTests: XCTestCase {
    func testQuotesTrimming() {
        let expectedKey = "key"
        let screenedKey = String.quote + expectedKey + String.quote

        let actualKey = screenedKey.trimmingQuotes()

        XCTAssertEqual(expectedKey, actualKey)
    }

    func testNoChangeIfNotSymmetric() {
        let testKey = String.quote + "key"
        let trimmedKey = testKey.trimmingQuotes()

        XCTAssertEqual(testKey, trimmedKey)
    }
}

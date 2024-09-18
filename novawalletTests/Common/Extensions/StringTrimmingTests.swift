import XCTest
@testable import novawallet

final class StringTrimmingTests: XCTestCase {
    func testScreenQuotesTrimming() {
        let expectedKey = "key"
        let screenedKey = String.screenQuote + expectedKey + String.screenQuote
        
        let actualKey = screenedKey.trimmingScreenQuotes()
        
        XCTAssertEqual(expectedKey, actualKey)
    }
    
    func testNoChangeIfNotSymmetric() {
        let testKey = String.screenQuote + "key"
        let trimmedKey = testKey.trimmingScreenQuotes()
        
        XCTAssertEqual(testKey, trimmedKey)
    }
}

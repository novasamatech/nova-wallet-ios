import XCTest
@testable import novawallet

final class URLOriginTests: XCTestCase {
    func testOriginsComparison() {
        performTest(str1: "https://host:20/path", str2: "https://host:20/path", sameOrigin: true)
        performTest(str1: "https://host:20/path", str2: "https://host:20/path?q=5", sameOrigin: true)
        performTest(str1: "https://host:20/path", str2: "https://host:20/path/p2?q=5", sameOrigin: true)
        performTest(str1: "https://host:20/path", str2: "https://host:10/path", sameOrigin: false)
        performTest(str1: "https://host:20/path", str2: "http://host:20/path", sameOrigin: false)
        performTest(str1: "https://host:20/path", str2: "https://hst:20/path", sameOrigin: false)
    }

    private func performTest(str1: String, str2: String, sameOrigin: Bool) {
        let url1 = URL(string: str1)!
        let url2 = URL(string: str2)!

        if sameOrigin {
            XCTAssertTrue(URL.hasSameOrigin(url1, url2))
        } else {
            XCTAssertFalse(URL.hasSameOrigin(url1, url2))
        }
    }
}

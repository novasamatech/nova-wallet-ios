import XCTest
@testable import novawallet

final class ScientificStringParsing: XCTestCase {
    func testSuccessCases() {
        performTest(for: "2.5115042144271755e+21", expected: "2511504214427175500000")
        performTest(for: "2.5115042144271755E+21", expected: "2511504214427175500000")
        performTest(for: "2.52e+3", expected: "2520")
        performTest(for: "2e+2", expected: "200")
    }

    func testFailingCases() {
        performTest(for: "2511504214427175500000", expected: nil)
        performTest(for: "2.5115042144271755e-2", expected: nil)
    }

    private func performTest(for intput: String, expected: String?) {
        let actual = intput.convertFromScientificUInt()

        XCTAssertEqual(actual, expected)
    }
}

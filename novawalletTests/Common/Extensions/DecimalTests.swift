import XCTest
@testable import novawallet

class DecimalTests: XCTestCase {
    func testDecimalFloor() {
        XCTAssertEqual(Decimal(0.1).floor(), 0.0)
        XCTAssertEqual(Decimal(0.5).floor(), 0.0)
        XCTAssertEqual(Decimal(0.9).floor(), 0.0)
        XCTAssertEqual(Decimal(5.1).floor(), 5.0)
        XCTAssertEqual(Decimal(5.5).floor(), 5.0)
        XCTAssertEqual(Decimal(5.9).floor(), 5.0)

        XCTAssertEqual(Decimal(-0.1).floor(), -1.0)
        XCTAssertEqual(Decimal(-0.5).floor(), -1.0)
        XCTAssertEqual(Decimal(-0.9).floor(), -1.0)
        XCTAssertEqual(Decimal(-5.1).floor(), -6.0)
        XCTAssertEqual(Decimal(-5.5).floor(), -6.0)
        XCTAssertEqual(Decimal(-5.9).floor(), -6.0)
    }
}

import XCTest
@testable import NovaAuth

final class NovaAuthClockTests: XCTestCase {
    func testContinuousTimeConversionAndStableActualBootIdentity() throws {
        let clock = NovaAuthContinuousClock { (9_000_000_000, 125, 3, 1_700_000_000, 123_456) }
        let time = try clock.now()
        XCTAssertEqual(time.continuousSeconds, 375)
        XCTAssertEqual(time.bootID, "1700000000:123456")
        XCTAssertEqual(time, try clock.now())
        let reboot = NovaAuthContinuousClock { (9_000_000_000, 125, 3, 1_700_000_001, 123_456) }
        XCTAssertNotEqual(time.bootID, try reboot.now().bootID)
    }

    func testClockReadFailuresNeverFallBackToWallTime() {
        for sample: (UInt64, UInt32, UInt32, Int64, Int32) in [(1, 0, 1, 1, 0), (1, 1, 0, 1, 0),
                                                               (1, 1, 1, 0, 0), (1, 1, 1, 1, -1), (1, 1, 1, 1, 1_000_000)] {
            XCTAssertThrowsError(try NovaAuthContinuousClock(read: { sample }).now()) {
                XCTAssertEqual($0 as? NovaAuthError, .clockUnavailable)
            }
        }
        XCTAssertThrowsError(try NovaAuthContinuousClock(read: { throw NovaAuthError.invalidResponse }).now()) {
            XCTAssertEqual($0 as? NovaAuthError, .clockUnavailable)
        }
    }

    func testSystemRandomMeetsClientIDAndJitterContract() throws {
        let random = NovaAuthSystemRandom()
        for _ in 0 ..< 32 {
            try NovaAuthValidation.clientID(random.makeClientID())
            XCTAssertTrue((0 ... 1).contains(random.unitInterval()))
        }
    }
}

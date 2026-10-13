import XCTest
@testable import NovaAuth

final class NovaAuthClockTests: XCTestCase {
    func testSystemRandomMeetsClientIDAndJitterContract() throws {
        let random = NovaAuthSystemRandom()
        for _ in 0 ..< 32 {
            try NovaAuthValidation.clientID(random.makeClientID())
            XCTAssertTrue((0 ... 1).contains(random.unitInterval()))
        }
    }
}

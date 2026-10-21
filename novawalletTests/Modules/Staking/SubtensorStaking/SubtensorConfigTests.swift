import XCTest
@testable import novawallet

final class SubtensorConfigTests: XCTestCase {
    func testConfigUsesTheConfiguredSwapFee() throws {
        let config = try decodeConfig(#"{"swapFee":0.005,"subnets":[]}"#)

        XCTAssertEqual(config.novaFeeRate?.decimalValue, Decimal(string: "0.005"))
    }

    func testConfigDropsAnOutOfRangeSwapFee() throws {
        let config = try decodeConfig(#"{"swapFee":1,"subnets":[]}"#)

        XCTAssertNil(config.novaFeeRate)
    }

    private func decodeConfig(_ json: String) throws -> SubtensorConfig {
        try JSONDecoder().decode(SubtensorConfig.self, from: Data(json.utf8))
    }
}

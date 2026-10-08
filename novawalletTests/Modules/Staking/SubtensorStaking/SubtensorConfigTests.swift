@testable import novawallet
import XCTest

final class SubtensorConfigTests: XCTestCase {
    func testSwapFeeDecodesToAnExactRate() throws {
        let config = try decodeConfig(#"{"swapFee":0.003,"subnets":[]}"#)

        XCTAssertEqual(config.novaFeeRate?.decimalValue, Decimal(string: "0.003"))
    }

    func testStoreUsesTheConfiguredSwapFee() throws {
        let store = SubtensorNovaFeeRateStore()

        store.apply(try decodeConfig(#"{"swapFee":0.005,"subnets":[]}"#))

        XCTAssertEqual(store.rate.decimalValue, Decimal(string: "0.005"))
    }

    func testStoreFallsBackWhenSwapFeeIsMissing() throws {
        let store = SubtensorNovaFeeRateStore()

        store.apply(try decodeConfig(#"{"subnets":[]}"#))

        XCTAssertEqual(store.rate, SubtensorNovaFeeConstants.fallbackRate)
    }

    func testStoreFallsBackWhenSwapFeeIsOutOfRange() throws {
        let store = SubtensorNovaFeeRateStore()

        store.apply(try decodeConfig(#"{"swapFee":1,"subnets":[]}"#))

        XCTAssertEqual(store.rate, SubtensorNovaFeeConstants.fallbackRate)
    }

    private func decodeConfig(_ json: String) throws -> SubtensorConfig {
        try JSONDecoder().decode(SubtensorConfig.self, from: Data(json.utf8))
    }
}

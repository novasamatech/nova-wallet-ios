import XCTest
@testable import novawallet

final class SubtensorConfigTests: XCTestCase {
    func testStoreUsesTheConfiguredSwapFee() throws {
        let store = SubtensorNovaFeeRateStore()

        store.apply(try decodeConfig(#"{"swapFee":0.005,"subnets":[]}"#))

        XCTAssertEqual(store.rate.decimalValue, Decimal(string: "0.005"))
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

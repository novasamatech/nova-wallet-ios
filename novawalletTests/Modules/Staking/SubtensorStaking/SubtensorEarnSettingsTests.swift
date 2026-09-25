import XCTest
@testable import novawallet
import Keystore_iOS

final class SubtensorEarnSettingsTests: XCTestCase {
    func testFreshSettingsDefaultToHalfPercentSlippageAndNothingElse() {
        let settings = SubtensorEarnSettings(settingsManager: InMemorySettingsManager())

        XCTAssertEqual(settings.slippageTolerance, BigRational(numerator: 5, denominator: 1000))
        XCTAssertEqual(settings.favouriteSubnets, [])
        XCTAssertNil(settings.lastStrategy)
    }

    func testSettingsRoundTripExactlyThroughTheSettingsManager() {
        let settingsManager = InMemorySettingsManager()
        let favourites = [
            SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295),
            SubtensorSubnetRef(netuid: 1, registeredAt: 3_989_825)
        ]

        let writer = SubtensorEarnSettings(settingsManager: settingsManager)
        writer.slippageTolerance = BigRational(numerator: 7, denominator: 3000)
        writer.favouriteSubnets = favourites
        writer.lastStrategy = .higherUpside

        let reader = SubtensorEarnSettings(settingsManager: settingsManager)

        XCTAssertEqual(reader.slippageTolerance, BigRational(numerator: 7, denominator: 3000))
        XCTAssertEqual(reader.favouriteSubnets, favourites)
        XCTAssertEqual(reader.lastStrategy, .higherUpside)
    }
}

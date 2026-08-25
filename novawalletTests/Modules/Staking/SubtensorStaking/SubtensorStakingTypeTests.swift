import XCTest
@testable import novawallet

final class SubtensorStakingTypeTests: XCTestCase {
    func testSubtensorRawTypeDecodes() {
        XCTAssertEqual(StakingType(rawType: "subtensor"), .subtensor)
    }

    func testUnknownRawTypeDegradesToUnsupported() {
        XCTAssertEqual(StakingType(rawType: "subtensor-root"), .unsupported)
    }

    func testNilRawTypeDegradesToUnsupported() {
        XCTAssertEqual(StakingType(rawType: nil), .unsupported)
    }

    func testNominationPoolsMorePreferredThanSubtensor() {
        XCTAssertTrue(StakingType.nominationPools.isMorePreferred(than: .subtensor))
        XCTAssertFalse(StakingType.subtensor.isMorePreferred(than: .nominationPools))
    }

    func testSubtensorMorePreferredThanUnsupported() {
        XCTAssertTrue(StakingType.subtensor.isMorePreferred(than: .unsupported))
        XCTAssertFalse(StakingType.unsupported.isMorePreferred(than: .subtensor))
    }

    func testAssetWithSubtensorStakingDetected() {
        let asset = createAsset(stakings: [.subtensor])

        XCTAssertTrue(asset.hasSubtensorStaking)
        XCTAssertTrue(asset.hasStaking)
        XCTAssertEqual(asset.supportedStakings, [.subtensor])
    }

    func testAssetWithOtherStakingNotDetectedAsSubtensor() {
        XCTAssertFalse(createAsset(stakings: [.relaychain]).hasSubtensorStaking)
    }

    func testAssetWithoutStakingsNotDetectedAsSubtensor() {
        XCTAssertFalse(createAsset(stakings: nil).hasSubtensorStaking)
    }

    private func createAsset(stakings: [StakingType]?) -> AssetModel {
        AssetModel(
            assetId: 0,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: stakings,
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            enabled: true,
            source: .remote
        )
    }
}

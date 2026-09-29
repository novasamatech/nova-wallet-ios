import XCTest
@testable import novawallet

final class BittensorApiFixtureModeStakingTests: XCTestCase {
    func testFixtureModeAddsSubtensorStakingToTheBittensorUtilityAssetOnly() {
        let utilityAsset = createAsset(assetId: AssetModel.utilityAssetId, stakings: nil)
        let nonUtilityAsset = createAsset(assetId: 1, stakings: nil)

        let bittensorAssets = BittensorApiFixtureMode.applyingSubtensorStaking(
            to: [utilityAsset, nonUtilityAsset],
            chainId: KnowChainId.bittensor,
            isEnabled: true
        )

        let otherChainAssets = BittensorApiFixtureMode.applyingSubtensorStaking(
            to: [utilityAsset],
            chainId: KnowChainId.polkadot,
            isEnabled: true
        )

        XCTAssertEqual(
            bittensorAssets,
            [createAsset(assetId: AssetModel.utilityAssetId, stakings: [.subtensor]), nonUtilityAsset]
        )
        XCTAssertEqual(otherChainAssets, [utilityAsset])
    }

    private func createAsset(assetId: AssetModel.Id, stakings: [StakingType]?) -> AssetModel {
        AssetModel(
            assetId: assetId,
            icon: "https://example.com/tao.svg",
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: "bittensor",
            stakings: stakings,
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )
    }
}

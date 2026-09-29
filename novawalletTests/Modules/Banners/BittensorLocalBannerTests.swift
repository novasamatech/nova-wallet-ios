import XCTest
@testable import novawallet

final class BittensorLocalBannerTests: XCTestCase {
    func testAssetWithoutSubtensorStakingHidesTheBanner() {
        let chain = createBittensorChain(stakings: nil)

        XCTAssertNil(BittensorLocalBanner.chainAsset(for: chain))
    }

    func testAssetWithSubtensorStakingShowsTheBanner() {
        let chain = createBittensorChain(stakings: [.subtensor])

        XCTAssertEqual(
            BittensorLocalBanner.chainAsset(for: chain)?.chainAssetId,
            ChainAssetId(chainId: KnowChainId.bittensor, assetId: AssetModel.utilityAssetId)
        )
    }

    private func createBittensorChain(stakings: [StakingType]?) -> ChainModel {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
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
            source: .remote
        )

        return ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )
    }
}

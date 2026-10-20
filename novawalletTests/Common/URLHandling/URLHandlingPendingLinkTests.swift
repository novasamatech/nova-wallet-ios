import XCTest
@testable import novawallet

final class URLHandlingPendingLinkTests: XCTestCase {
    /// Shape of the staking case persisted by app versions that had no payload.
    private enum LegacyPendingLink: Codable {
        case staking
    }

    func testLegacyStakingLinkDecodesWithoutNavigation() throws {
        let data = try JSONEncoder().encode(LegacyPendingLink.staking)

        let link = try JSONDecoder().decode(URLHandlingPendingLink.self, from: data)

        guard case .staking(chainAssetId: nil) = link else {
            return XCTFail("Unexpected link: \(link)")
        }
    }

    func testStakingLinkWithChainAssetRoundTrips() throws {
        let chainAssetId = ChainAssetId(chainId: KnowChainId.bittensor, assetId: 0)

        let data = try JSONEncoder().encode(URLHandlingPendingLink.staking(chainAssetId: chainAssetId))
        let link = try JSONDecoder().decode(URLHandlingPendingLink.self, from: data)

        guard case let .staking(decodedChainAssetId) = link else {
            return XCTFail("Unexpected link: \(link)")
        }

        XCTAssertEqual(decodedChainAssetId, chainAssetId)
    }

    func testStakingScreenMapsToPendingLinkAndBack() {
        let navigation = StakingNavigation(chainAssetId: ChainAssetId(chainId: KnowChainId.bittensor, assetId: 0))

        guard let pendingLink = UrlHandlingScreen.staking(navigation).pendingLink else {
            return XCTFail("Pending link is missing")
        }

        guard case let .staking(restoredNavigation) = UrlHandlingScreen(pendingLink: pendingLink) else {
            return XCTFail("Unexpected screen")
        }

        XCTAssertEqual(restoredNavigation, navigation)
    }
}

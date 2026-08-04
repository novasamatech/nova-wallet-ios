import XCTest
@testable import novawallet

final class StakingConstantsTests: XCTestCase {
    func testForcedPoolChainsAreAssetHubs() {
        XCTAssertEqual(
            StakingConstants.forcedPoolChainIds,
            [KnowChainId.polkadotAssetHub, KnowChainId.kusamaAssetHub]
        )
    }

    func testForcedPoolChainsHaveRecommendedPool() {
        let chainsWithNovaPool = Set(StakingConstants.recommendedPoolIds.keys)

        XCTAssertTrue(
            StakingConstants.forcedPoolChainIds.isSubset(of: chainsWithNovaPool),
            "A forced chain without a recommended pool leaves the user with no selectable pool"
        )
    }

    func testIsPoolForced() {
        XCTAssertTrue(StakingConstants.isPoolForced(for: KnowChainId.polkadotAssetHub))
        XCTAssertTrue(StakingConstants.isPoolForced(for: KnowChainId.kusamaAssetHub))
        XCTAssertFalse(StakingConstants.isPoolForced(for: KnowChainId.polkadot))
        XCTAssertFalse(StakingConstants.isPoolForced(for: KnowChainId.alephZero))
    }
}

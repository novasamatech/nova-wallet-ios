import XCTest
@testable import novawallet

final class SubtensorRootClaimRuleTests: XCTestCase {
    func testOnlyRewardsFromTheChainMinimumUpAreClaimable() {
        let minimumClaim = SubtensorRootClaimRule.minimumClaim(fromThresholdBits: nil)

        XCTAssertEqual(minimumClaim, SubtensorRootClaimRule.minimumClaim(fromThresholdBits: Balance(500_000) << 32))
        XCTAssertFalse(isClaimable(redeemable: 499_999, minimumClaim: minimumClaim))
        XCTAssertTrue(isClaimable(redeemable: 500_000, minimumClaim: minimumClaim))
        XCTAssertTrue(isClaimable(redeemable: 500_001, minimumClaim: minimumClaim))
    }

    func testFractionalThresholdRoundsTheMinimumUp() {
        let minimumClaim = SubtensorRootClaimRule.minimumClaim(fromThresholdBits: (Balance(500_000) << 32) + 1)

        XCTAssertEqual(minimumClaim, 500_001)
        XCTAssertFalse(isClaimable(redeemable: 500_000, minimumClaim: minimumClaim))
    }

    func testZeroThresholdStillNeedsAPayout() {
        let minimumClaim = SubtensorRootClaimRule.minimumClaim(fromThresholdBits: 0)

        XCTAssertFalse(isClaimable(redeemable: 0, minimumClaim: minimumClaim))
        XCTAssertTrue(isClaimable(redeemable: 1, minimumClaim: minimumClaim))
    }

    private func isClaimable(redeemable: Balance, minimumClaim: Balance) -> Bool {
        SubtensorRootClaimRule.isClaimable(
            SubtensorRootClaimPreview(
                hotkey: Data(repeating: 1, count: 32),
                redeemable: redeemable,
                forfeitedEstimate: 0,
                minimumClaim: minimumClaim
            )
        )
    }
}

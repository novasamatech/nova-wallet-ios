import XCTest
@testable import novawallet
import BigInt

final class SubtensorClaimRewardsStateTests: XCTestCase {
    private let hotkey1 = Data(repeating: 0x11, count: 32)
    private let hotkey2 = Data(repeating: 0x22, count: 32)
    private let hotkey3 = Data(repeating: 0x33, count: 32)

    private func makeState(
        payouts: [(Data, BigUInt)],
        threshold: BigUInt
    ) -> SubtensorClaimRewardsState {
        let positions = payouts.map { hotkey, payout in
            SubtensorStakingPallet.RootBasketPosition(
                hotkey: hotkey,
                owedShares: 1,
                payout: payout
            )
        }

        let owed = payouts.reduce(BigUInt.zero) { $0 + $1.1 }

        return SubtensorClaimRewardsState(
            claimable: SubtensorRootClaimable(owed: owed, positions: positions),
            threshold: threshold
        )
    }

    func testEligibleExcludesSubThresholdPositions() {
        let state = makeState(
            payouts: [(hotkey1, 1_000_000), (hotkey2, 400_000)],
            threshold: 500_000
        )

        XCTAssertEqual(state.eligibleHotkeys, [hotkey1])
    }

    func testEligibleExcludesZeroPayout() {
        let state = makeState(
            payouts: [(hotkey1, 0), (hotkey2, 600_000)],
            threshold: 0
        )

        XCTAssertEqual(state.eligibleHotkeys, [hotkey2])
    }

    func testEligibleTotalSumsOnlyEligiblePayouts() {
        let state = makeState(
            payouts: [(hotkey1, 1_000_000), (hotkey2, 700_000), (hotkey3, 100_000)],
            threshold: 500_000
        )

        XCTAssertEqual(state.eligibleTotal, 1_700_000)
    }

    func testPendingTotalSumsSubThresholdPayouts() {
        let state = makeState(
            payouts: [(hotkey1, 1_000_000), (hotkey2, 300_000), (hotkey3, 100_000)],
            threshold: 500_000
        )

        XCTAssertEqual(state.pendingTotal, 400_000)
    }

    func testAllSubThresholdYieldsNoEligibleHotkeys() {
        let state = makeState(
            payouts: [(hotkey1, 100), (hotkey2, 200)],
            threshold: 500_000
        )

        XCTAssertTrue(state.eligibleHotkeys.isEmpty)
        XCTAssertEqual(state.eligibleTotal, 0)
    }

    func testTotalFeeMultipliesSingleClaimFeeByEligibleCount() {
        let state = makeState(
            payouts: [(hotkey1, 1_000_000), (hotkey2, 700_000), (hotkey3, 100_000)],
            threshold: 500_000
        )

        let singleFee = ExtrinsicFee(amount: 250, payer: nil, weight: .zero)

        XCTAssertEqual(state.totalFee(from: singleFee).amount, 500)
    }
}

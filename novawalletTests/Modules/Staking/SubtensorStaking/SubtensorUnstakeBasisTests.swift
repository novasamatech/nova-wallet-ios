import BigInt
@testable import novawallet
import XCTest

final class SubtensorUnstakeBasisTests: XCTestCase {
    private func makeAvailability(
        total: Balance,
        locked: Balance,
        available: Balance
    ) -> SubtensorStakingPallet.StakeAvailability {
        SubtensorStakingPallet.StakeAvailability(total: total, locked: locked, available: available)
    }

    func testMissingAvailabilityLeavesTheWholeStakeAvailable() {
        let basis = SubtensorUnstakeBasis.make(staked: 1000, availability: nil)

        XCTAssertEqual(basis.available, 1000)
        XCTAssertEqual(basis.locked, 0)
    }

    func testAvailabilityCapsTheStake() {
        let basis = SubtensorUnstakeBasis.make(
            staked: 1000,
            availability: makeAvailability(total: 1000, locked: 400, available: 600)
        )

        XCTAssertEqual(basis.available, 600)
    }

    func testPositionStakeCapsColdkeyWideAvailability() {
        let basis = SubtensorUnstakeBasis.make(
            staked: 1000,
            availability: makeAvailability(total: 5000, locked: 0, available: 5000)
        )

        XCTAssertEqual(basis.available, 1000)
    }

    func testLockedIsTheStakeBeyondWhatIsAvailable() {
        let basis = SubtensorUnstakeBasis.make(
            staked: 1000,
            availability: makeAvailability(total: 5000, locked: 4400, available: 600)
        )

        XCTAssertEqual(basis.locked, 400)
    }

    func testZeroAvailabilityOnFundedPositionIsFullyLocked() {
        let basis = SubtensorUnstakeBasis.make(
            staked: 1000,
            availability: makeAvailability(total: 1000, locked: 1000, available: 0)
        )

        XCTAssertTrue(basis.isFullyLocked)
        XCTAssertFalse(basis.isFullyAvailable)
    }

    func testEmptyPositionIsNotFullyLocked() {
        let basis = SubtensorUnstakeBasis.make(
            staked: 0,
            availability: makeAvailability(total: 0, locked: 0, available: 0)
        )

        XCTAssertFalse(basis.isFullyLocked)
    }

    func testUnlockedPositionIsFullyAvailable() {
        let basis = SubtensorUnstakeBasis.make(
            staked: 1000,
            availability: makeAvailability(total: 1000, locked: 0, available: 1000)
        )

        XCTAssertTrue(basis.isFullyAvailable)
    }
}

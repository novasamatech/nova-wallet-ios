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

    func testFullyAvailableGroupExitsEveryHotkeyAtTheGroupTotal() {
        let basis = SubtensorGroupUnstakeBasis.make(from: makeRootGroup())

        XCTAssertEqual(basis.max, 20_000_000_000)
        XCTAssertEqual(basis.exitHotkeys(for: 20_000_000_000), [primaryHotkey, secondHotkey])
    }

    func testAmountAboveThePrimaryCapBelowTheGroupTotalIsNoExit() {
        let basis = SubtensorGroupUnstakeBasis.make(from: makeRootGroup())

        XCTAssertEqual(basis.partialCap, 15_000_000_000)
        XCTAssertNil(basis.exitHotkeys(for: 17_000_000_000))
    }

    func testColdkeyWideLockCapsMaxAtTheAvailablePrimaryStake() {
        let group = SubtensorPortfolioGroup(
            netuid: 64,
            positions: [makePosition(hotkey: primaryHotkey, netuid: 64, stakeAlpha: 70_200_000_000)],
            totalAlpha: 70_200_000_000,
            taoValue: nil,
            availability: makeAvailability(total: 70_200_000_000, locked: 14_000_000_000, available: 56_200_000_000),
            primaryHotkey: primaryHotkey
        )

        let basis = SubtensorGroupUnstakeBasis.make(from: group)

        XCTAssertEqual(basis.locked, 14_000_000_000)
        XCTAssertEqual(basis.max, 56_200_000_000)
        XCTAssertNil(basis.exitHotkeys(for: 56_200_000_000))
    }

    private var primaryHotkey: AccountId {
        Data(repeating: 0xAA, count: 32)
    }

    private var secondHotkey: AccountId {
        Data(repeating: 0xBB, count: 32)
    }

    private func makePosition(hotkey: AccountId, netuid: UInt16, stakeAlpha: Balance) -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: hotkey,
            netuid: netuid,
            stakeAlpha: stakeAlpha,
            hotkeyEmissionPerTempo: 0,
            totalHotkeyAlpha: nil,
            isRegistered: true
        )
    }

    private func makeRootGroup() -> SubtensorPortfolioGroup {
        let rootNetuid = SubtensorStakingPallet.rootNetuid

        return SubtensorPortfolioGroup(
            netuid: rootNetuid,
            positions: [
                makePosition(hotkey: primaryHotkey, netuid: rootNetuid, stakeAlpha: 15_000_000_000),
                makePosition(hotkey: secondHotkey, netuid: rootNetuid, stakeAlpha: 5_000_000_000)
            ],
            totalAlpha: 20_000_000_000,
            taoValue: 20_000_000_000,
            availability: nil,
            primaryHotkey: primaryHotkey
        )
    }
}

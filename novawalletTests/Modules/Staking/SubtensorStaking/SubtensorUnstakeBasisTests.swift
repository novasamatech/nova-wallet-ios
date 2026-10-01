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

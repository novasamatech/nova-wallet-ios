import BigInt
@testable import novawallet
import XCTest

final class SubtensorUnstakePlanTests: XCTestCase {
    private let primary = SubtensorUnstakeSlice(hotkey: Data(repeating: 0x0A, count: 32), alpha: 60_000_000_000)
    private let second = SubtensorUnstakeSlice(hotkey: Data(repeating: 0x0B, count: 32), alpha: 40_000_000_000)
    private let third = SubtensorUnstakeSlice(hotkey: Data(repeating: 0x0C, count: 32), alpha: 30_000_000_000)
    private let floor: Balance = 2_000_000_000

    func testAmountWithinThePrimaryIsASinglePartialFromIt() {
        let plan = makeBasis().plan(for: 50_000_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [], partial: slice(primary, 50_000_000_000)))
    }

    func testAmountAboveThePrimaryEmptiesTheSmallestPositionsFirst() {
        let plan = makeBasis().plan(for: 61_000_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [third], partial: slice(second, 31_000_000_000)))
    }

    func testAmountEqualToEverythingExitsAllHotkeys() {
        let plan = makeBasis().plan(for: 130_000_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [third, second, primary], partial: nil))
    }

    func testSliceBelowTheFloorIsDroppedOnATie() {
        let plan = makeBasis().plan(for: 71_000_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [third, second], partial: nil))
    }

    func testRemainderBelowTheFloorTrimsTheSlice() {
        let plan = makeBasis().plan(for: 69_000_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [third], partial: slice(second, 38_000_000_000)))
    }

    func testRemainderBelowTheFloorExitsThePositionWhenCloser() {
        let plan = makeBasis().plan(for: 69_500_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [third, second], partial: nil))
    }

    func testAmountAboveTheAvailableStakeHasNoPlan() {
        let plan = makeBasis(available: 100_000_000_000).plan(for: 101_000_000_000, floor: floor)

        XCTAssertNil(plan)
    }

    func testHeldHotkeyIsNotDrawnFrom() {
        let group = SubtensorPortfolioGroup(
            netuid: 0,
            positions: [primary, second].map { position($0) },
            totalAlpha: 100_000_000_000,
            redeemable: 0,
            taoValue: nil,
            availability: nil,
            primaryHotkey: primary.hotkey
        )

        let basis = SubtensorGroupUnstakeBasis.make(from: group, excluding: [primary.hotkey])

        XCTAssertEqual(basis.max, second.alpha)
        XCTAssertEqual(basis.plan(for: second.alpha, floor: floor), SubtensorUnstakePlan(exits: [second], partial: nil))
    }

    private func makeBasis(available: Balance = 130_000_000_000) -> SubtensorGroupUnstakeBasis {
        SubtensorGroupUnstakeBasis(total: 130_000_000_000, available: available, positions: [primary, second, third])
    }

    private func slice(_ position: SubtensorUnstakeSlice, _ alpha: Balance) -> SubtensorUnstakeSlice {
        SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: alpha)
    }

    private func position(_ slice: SubtensorUnstakeSlice) -> SubtensorStakingPosition {
        SubtensorStakingPosition(hotkey: slice.hotkey, netuid: 0, stakeAlpha: slice.alpha, isRegistered: true)
    }
}

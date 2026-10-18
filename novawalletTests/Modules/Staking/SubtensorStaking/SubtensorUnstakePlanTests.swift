import BigInt
@testable import novawallet
import XCTest

final class SubtensorUnstakePlanTests: XCTestCase {
    private let primary = SubtensorUnstakePosition(hotkey: Data(repeating: 0x0A, count: 32), alpha: 60_000_000_000, locked: 0)
    private let second = SubtensorUnstakePosition(hotkey: Data(repeating: 0x0B, count: 32), alpha: 40_000_000_000, locked: 0)
    private let third = SubtensorUnstakePosition(hotkey: Data(repeating: 0x0C, count: 32), alpha: 30_000_000_000, locked: 0)
    private let floor: Balance = 2_000_000_000

    func testAmountWithinThePrimaryIsASinglePartialFromIt() {
        let plan = makeBasis().plan(for: 50_000_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [], partials: [slice(primary, 50_000_000_000)]))
    }

    func testAmountAboveThePrimaryEmptiesTheSmallestPositionsFirst() {
        let plan = makeBasis().plan(for: 61_000_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [exit(third)], partials: [slice(second, 31_000_000_000)]))
    }

    func testAmountEqualToEverythingExitsAllHotkeys() {
        let plan = makeBasis().plan(for: 130_000_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [exit(third), exit(second), exit(primary)], partials: []))
    }

    func testSliceBelowTheFloorIsDropped() {
        let plan = makeBasis().plan(for: 71_000_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [exit(third), exit(second)], partials: []))
    }

    func testRemainderBelowTheFloorTrimsTheSlice() {
        let plan = makeBasis().plan(for: 69_000_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [exit(third)], partials: [slice(second, 38_000_000_000)]))
    }

    func testRemainderBelowTheFloorExitsThePositionWhenCloser() {
        let plan = makeBasis().plan(for: 69_500_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [exit(third), exit(second)], partials: []))
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

        XCTAssertEqual(basis.max(floor: floor), second.alpha)
        XCTAssertEqual(basis.plan(for: second.alpha, floor: floor), SubtensorUnstakePlan(exits: [exit(second)], partials: []))
    }

    private func makeBasis(available: Balance = 130_000_000_000) -> SubtensorGroupUnstakeBasis {
        SubtensorGroupUnstakeBasis(total: 130_000_000_000, available: available, positions: [primary, second, third])
    }

    private func slice(_ position: SubtensorUnstakePosition, _ alpha: Balance) -> SubtensorUnstakeSlice {
        SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: alpha)
    }

    private func exit(_ position: SubtensorUnstakePosition) -> SubtensorUnstakeSlice {
        SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: position.alpha)
    }

    private func position(_ position: SubtensorUnstakePosition) -> SubtensorStakingPosition {
        SubtensorStakingPosition(hotkey: position.hotkey, netuid: 0, stakeAlpha: position.alpha, isRegistered: true)
    }
}

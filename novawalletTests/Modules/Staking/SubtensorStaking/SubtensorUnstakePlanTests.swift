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

    func testFloorSliceClearsTheValidatorMinimumOutWithThePoolFee() throws {
        let limitPrice: Balance = 50_000_000
        let feeRate: UInt16 = 33
        let floor = SubtensorGroupUnstakeBasis.floorAlpha(minTao: 2_000_000, price: limitPrice, feeRate: feeRate)

        let minimumOut = try SubtensorTradeQuoteOperationFactory.sellSwapMinimumOut(
            alpha: floor,
            feeRate: feeRate,
            limitPrice: limitPrice
        )

        XCTAssertGreaterThanOrEqual(minimumOut, 2_000_000)
    }

    func testCollateralHotkeyIsSlicedToItsFreePartInsteadOfExited() {
        let bonded = SubtensorUnstakePosition(hotkey: second.hotkey, alpha: second.alpha, locked: 10_000_000_000)
        let basis = SubtensorGroupUnstakeBasis(
            total: 100_000_000_000,
            available: 90_000_000_000,
            positions: [primary, bonded]
        )

        let plan = basis.plan(for: 61_000_000_000, floor: floor)

        XCTAssertEqual(
            plan,
            SubtensorUnstakePlan(exits: [], partials: [slice(bonded, 30_000_000_000), slice(primary, 31_000_000_000)])
        )
    }

    func testSelectedValidatorMaxIsItsStakeCappedBySubnetAvailability() {
        let group = makeGroup([primary, second], available: 50_000_000_000)

        let primaryBasis = makeBasis(group, selection: .validator(primary.hotkey))
        let secondBasis = makeBasis(group, selection: .validator(second.hotkey))

        XCTAssertEqual(primaryBasis.max(floor: floor), 50_000_000_000)
        XCTAssertEqual(secondBasis.max(floor: floor), second.alpha)
        XCTAssertNil(secondBasis.plan(for: 41_000_000_000, floor: floor))
    }

    func testSelectedValidatorDustRemainderSnapsToItsFullExit() {
        let basis = makeBasis(makeGroup([primary, second]), selection: .validator(primary.hotkey))

        let plan = basis.plan(for: 59_999_900_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [exit(primary)], partials: []))
    }

    func testAllValidatorsDustyPrimaryRemainderFallsToSmallestFirstSplit() {
        let plan = makeBasis().plan(for: 59_500_000_000, floor: floor)

        XCTAssertEqual(plan, SubtensorUnstakePlan(exits: [exit(third)], partials: [slice(second, 29_500_000_000)]))
    }

    func testAllValidatorsKeepTheSixteenLargestPositions() {
        let positions = (1 ... 18).map { index in
            SubtensorUnstakePosition(
                hotkey: Data(repeating: UInt8(index), count: 32),
                alpha: Balance(index) * floor,
                locked: 0
            )
        }
        let kept = positions.reversed().prefix(SubtensorGroupUnstakeBasis.maxLegs)

        let basis = makeBasis(makeGroup(Array(positions.reversed())), selection: .all)

        XCTAssertEqual(basis.positions, Array(kept))
        XCTAssertEqual(basis.max(floor: floor), kept.reduce(0) { $0 + $1.alpha })
        XCTAssertEqual(basis.plan(for: basis.max(floor: floor), floor: floor)?.slices.count, 16)
    }

    func testHeldValidatorIsLeftOutOfAllAndCannotStaySelected() {
        let group = makeGroup([primary, second, third])
        let held: Set<AccountId> = [primary.hotkey]

        let basis = makeBasis(group, selection: .all, excluding: held)
        let heldSelection = SubtensorUnstakeSelection.resolve(.validator(primary.hotkey), in: group, excluding: held)
        let soleSellable = SubtensorUnstakeSelection.resolve(.all, in: makeGroup([primary, second]), excluding: held)

        XCTAssertEqual(basis.total, second.alpha + third.alpha)
        XCTAssertEqual(heldSelection, .validator(second.hotkey))
        XCTAssertEqual(soleSellable, .validator(second.hotkey))
    }

    private func makeGroup(
        _ members: [SubtensorUnstakePosition],
        available: Balance? = nil
    ) -> SubtensorPortfolioGroup {
        let total = members.reduce(Balance.zero) { $0 + $1.alpha }

        return SubtensorPortfolioGroup(
            netuid: 0,
            positions: members.map { position($0) },
            totalAlpha: total,
            redeemable: 0,
            taoValue: nil,
            availability: SubtensorPallet.StakeAvailability(available: available ?? total),
            primaryHotkey: members[0].hotkey
        )
    }

    private func makeBasis(
        _ group: SubtensorPortfolioGroup,
        selection: SubtensorUnstakeSelection,
        excluding held: Set<AccountId> = []
    ) -> SubtensorGroupUnstakeBasis {
        SubtensorGroupUnstakeBasis.make(from: group, selection: selection, excluding: held, groupHotkeys: [:])
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

    private func position(_ position: SubtensorUnstakePosition) -> SubtensorPosition {
        SubtensorPosition(hotkey: position.hotkey, netuid: 0, stakeAlpha: position.alpha, isRegistered: true)
    }
}

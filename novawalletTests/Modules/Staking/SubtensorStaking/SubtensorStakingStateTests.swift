import XCTest
@testable import novawallet
import BigInt

final class SubtensorStakingStateTests: XCTestCase {
    func testRootPositionValuedAtFaceValue() {
        let state = Multistaking.SubtensorStakingState(
            positions: [Self.position(netuid: 0, stakeAlpha: 57_816_438)],
            prices: [:]
        )

        XCTAssertEqual(state.totalStakeInRao, BigUInt(57_816_438))
    }

    func testAlphaPositionValuedAtSpotPrice() {
        let state = Multistaking.SubtensorStakingState(
            positions: [Self.position(netuid: 5, stakeAlpha: 2_000_000_000)],
            prices: [5: 500_000_000]
        )

        XCTAssertEqual(state.totalStakeInRao, BigUInt(1_000_000_000))
    }

    func testAlphaValuationRoundsDown() {
        let state = Multistaking.SubtensorStakingState(
            positions: [Self.position(netuid: 5, stakeAlpha: 3)],
            prices: [5: 333_333_333]
        )

        XCTAssertEqual(state.totalStakeInRao, BigUInt.zero)
    }

    func testMixedPositionsSumRootAndSpotValuedAlpha() {
        let state = Multistaking.SubtensorStakingState(
            positions: [
                Self.position(netuid: 0, stakeAlpha: 1000),
                Self.position(netuid: 3, stakeAlpha: 10),
                Self.position(netuid: 4, stakeAlpha: 5)
            ],
            prices: [0: 1_000_000_000, 3: 2_000_000_000, 4: 1_000_000_000]
        )

        XCTAssertEqual(state.totalStakeInRao, BigUInt(1025))
    }

    func testLargeStakeValuationDoesNotOverflow() {
        let state = Multistaking.SubtensorStakingState(
            positions: [Self.position(netuid: 1, stakeAlpha: BigUInt(UInt64.max))],
            prices: [1: BigUInt(UInt64.max)]
        )

        XCTAssertEqual(state.totalStakeInRao, BigUInt("340282366920938463426481119284"))
    }

    func testStateWithPositionsMapsToActiveIndependent() {
        let state = Multistaking.SubtensorStakingState(
            positions: [Self.position(netuid: 0, stakeAlpha: 1)],
            prices: [:]
        )

        XCTAssertEqual(
            Multistaking.DashboardItemOnchainState.from(subtensorState: state),
            .activeIndependent
        )
    }

    func testEmptyStateMapsToNilOnchainState() {
        let state = Multistaking.SubtensorStakingState(positions: [], prices: [0: 1_000_000_000])

        XCTAssertNil(Multistaking.DashboardItemOnchainState.from(subtensorState: state))
    }

    private static func position(netuid: UInt16, stakeAlpha: BigUInt) -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: Data(repeating: 2, count: 32),
            netuid: netuid,
            stakeAlpha: stakeAlpha,
            hotkeyEmissionPerTempo: 0,
            totalHotkeyAlpha: nil,
            isRegistered: true
        )
    }
}

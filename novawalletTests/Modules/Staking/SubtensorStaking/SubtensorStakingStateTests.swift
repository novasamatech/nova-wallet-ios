import XCTest
@testable import novawallet
import BigInt

final class SubtensorStakingStateTests: XCTestCase {
    func testStateWithPositionsMapsToActiveIndependent() {
        let state = Multistaking.SubtensorStakingState(
            positions: [Self.position(netuid: 0, stakeAlpha: 1)]
        )

        XCTAssertEqual(
            Multistaking.DashboardItemOnchainState.from(subtensorState: state),
            .activeIndependent
        )
    }

    func testEmptyStateMapsToNilOnchainState() {
        let state = Multistaking.SubtensorStakingState(positions: [])

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

import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

final class SubtensorStakingCallModelTests: XCTestCase {
    private let hotkey = Data(repeating: 0x22, count: 32)

    private func applyToBuilder(_ call: SubtensorStakingCallModel) throws -> RecordingExtrinsicBuilder {
        let builder = RecordingExtrinsicBuilder()

        _ = try call.extrinsicBuilderClosure(builder)

        return builder
    }

    func testStakeBuildsAddStakeCall() throws {
        let model = SubtensorStakeModel(hotkey: hotkey, netuid: 0, amount: 1_000_000)

        let builder = try applyToBuilder(.stake(model))

        XCTAssertEqual(
            builder.addedCalls,
            [CallCodingPath(moduleName: "SubtensorModule", callName: "add_stake")]
        )

        let args = try XCTUnwrap(builder.addedCallArgs.first as? SubtensorStakingPallet.AddStakeCall)

        XCTAssertEqual(args.hotkey, hotkey)
        XCTAssertEqual(args.netuid, 0)
        XCTAssertEqual(args.amountStaked, 1_000_000)
    }

    func testPartialUnstakeBuildsRemoveStakeCall() throws {
        let model = SubtensorUnstakeModel(hotkey: hotkey, netuid: 0, amount: 500, isFullUnstake: false)

        let builder = try applyToBuilder(.unstake(model))

        XCTAssertEqual(
            builder.addedCalls,
            [CallCodingPath(moduleName: "SubtensorModule", callName: "remove_stake")]
        )

        let args = try XCTUnwrap(builder.addedCallArgs.first as? SubtensorStakingPallet.RemoveStakeCall)

        XCTAssertEqual(args.hotkey, hotkey)
        XCTAssertEqual(args.netuid, 0)
        XCTAssertEqual(args.amountUnstaked, 500)
    }

    func testFullUnstakeBuildsRemoveStakeFullLimitCallWithoutLimitPrice() throws {
        let model = SubtensorUnstakeModel(hotkey: hotkey, netuid: 0, amount: 500, isFullUnstake: true)

        let builder = try applyToBuilder(.unstake(model))

        XCTAssertEqual(
            builder.addedCalls,
            [CallCodingPath(moduleName: "SubtensorModule", callName: "remove_stake_full_limit")]
        )

        let args = try XCTUnwrap(
            builder.addedCallArgs.first as? SubtensorStakingPallet.RemoveStakeFullLimitCall
        )

        XCTAssertEqual(args.hotkey, hotkey)
        XCTAssertEqual(args.netuid, 0)
        XCTAssertNil(args.limitPrice)
    }

    func testClaimBuildsClaimRootWithHotkeyCall() throws {
        let builder = try applyToBuilder(.claim(hotkey: hotkey))

        XCTAssertEqual(
            builder.addedCalls,
            [CallCodingPath(moduleName: "SubtensorModule", callName: "claim_root_with_hotkey")]
        )

        let args = try XCTUnwrap(
            builder.addedCallArgs.first as? SubtensorStakingPallet.ClaimRootWithHotkeyCall
        )

        XCTAssertEqual(args.hotkey, hotkey)
    }

    func testStakeAmountAboveU64MaxThrows() {
        let model = SubtensorStakeModel(
            hotkey: hotkey,
            netuid: 0,
            amount: BigUInt(UInt64.max) + 1
        )

        XCTAssertThrowsError(try applyToBuilder(.stake(model)))
    }
}

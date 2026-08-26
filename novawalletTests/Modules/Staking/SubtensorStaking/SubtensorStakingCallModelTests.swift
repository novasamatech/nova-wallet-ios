import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

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

    func testStakeWithLimitPriceBuildsAddStakeLimitFillOrKill() throws {
        let model = SubtensorStakeModel(hotkey: hotkey, netuid: 5, amount: 1_000_000, limitPrice: 7_721_671)

        let builder = try applyToBuilder(.stake(model))

        XCTAssertEqual(
            builder.addedCalls,
            [CallCodingPath(moduleName: "SubtensorModule", callName: "add_stake_limit")]
        )

        let args = try XCTUnwrap(builder.addedCallArgs.first as? SubtensorStakingPallet.AddStakeLimitCall)

        XCTAssertEqual(args.hotkey, hotkey)
        XCTAssertEqual(args.netuid, 5)
        XCTAssertEqual(args.amountStaked, 1_000_000)
        XCTAssertEqual(args.limitPrice, 7_721_671)
        XCTAssertFalse(args.allowPartial)
    }

    func testPartialUnstakeWithLimitPriceBuildsRemoveStakeLimitFillOrKill() throws {
        let model = SubtensorUnstakeModel(
            hotkey: hotkey,
            netuid: 5,
            amount: 500,
            isFullUnstake: false,
            limitPrice: 7_644_839
        )

        let builder = try applyToBuilder(.unstake(model))

        XCTAssertEqual(
            builder.addedCalls,
            [CallCodingPath(moduleName: "SubtensorModule", callName: "remove_stake_limit")]
        )

        let args = try XCTUnwrap(builder.addedCallArgs.first as? SubtensorStakingPallet.RemoveStakeLimitCall)

        XCTAssertEqual(args.hotkey, hotkey)
        XCTAssertEqual(args.netuid, 5)
        XCTAssertEqual(args.amountUnstaked, 500)
        XCTAssertEqual(args.limitPrice, 7_644_839)
        XCTAssertFalse(args.allowPartial)
    }

    func testFullUnstakeWithLimitPriceBuildsRemoveStakeFullLimitWithSome() throws {
        let model = SubtensorUnstakeModel(
            hotkey: hotkey,
            netuid: 5,
            amount: 500,
            isFullUnstake: true,
            limitPrice: 7_644_839
        )

        let builder = try applyToBuilder(.unstake(model))

        XCTAssertEqual(
            builder.addedCalls,
            [CallCodingPath(moduleName: "SubtensorModule", callName: "remove_stake_full_limit")]
        )

        let args = try XCTUnwrap(
            builder.addedCallArgs.first as? SubtensorStakingPallet.RemoveStakeFullLimitCall
        )

        XCTAssertEqual(args.hotkey, hotkey)
        XCTAssertEqual(args.netuid, 5)
        XCTAssertEqual(args.limitPrice, 7_644_839)
    }

    func testStakeAmountAboveU64MaxThrows() {
        let model = SubtensorStakeModel(
            hotkey: hotkey,
            netuid: 0,
            amount: BigUInt(UInt64.max) + 1
        )

        XCTAssertThrowsError(try applyToBuilder(.stake(model)))
    }

    func testRootStakeWithoutLimitPricePassesSlippageProtection() throws {
        let model = SubtensorStakeModel(hotkey: hotkey, netuid: 0, amount: 1_000_000)

        try SubtensorStakingCallModel.stake(model).ensureSlippageProtected()
    }

    func testSubnetStakeWithoutLimitPriceFailsSlippageProtection() {
        let model = SubtensorStakeModel(hotkey: hotkey, netuid: 5, amount: 1_000_000)

        XCTAssertThrowsError(try SubtensorStakingCallModel.stake(model).ensureSlippageProtected())
    }

    func testSubnetStakeWithLimitPricePassesSlippageProtection() throws {
        let model = SubtensorStakeModel(hotkey: hotkey, netuid: 5, amount: 1_000_000, limitPrice: 7_721_671)

        try SubtensorStakingCallModel.stake(model).ensureSlippageProtected()
    }

    func testRootUnstakeWithoutLimitPricePassesSlippageProtection() throws {
        let model = SubtensorUnstakeModel(hotkey: hotkey, netuid: 0, amount: 500, isFullUnstake: false)

        try SubtensorStakingCallModel.unstake(model).ensureSlippageProtected()
    }

    func testSubnetPartialUnstakeWithoutLimitPriceFailsSlippageProtection() {
        let model = SubtensorUnstakeModel(hotkey: hotkey, netuid: 5, amount: 500, isFullUnstake: false)

        XCTAssertThrowsError(try SubtensorStakingCallModel.unstake(model).ensureSlippageProtected())
    }

    func testSubnetFullUnstakeWithoutLimitPriceFailsSlippageProtection() {
        let model = SubtensorUnstakeModel(hotkey: hotkey, netuid: 5, amount: 500, isFullUnstake: true)

        XCTAssertThrowsError(try SubtensorStakingCallModel.unstake(model).ensureSlippageProtected())
    }

    func testSubnetFullUnstakeWithLimitPricePassesSlippageProtection() throws {
        let model = SubtensorUnstakeModel(
            hotkey: hotkey,
            netuid: 5,
            amount: 500,
            isFullUnstake: true,
            limitPrice: 7_644_839
        )

        try SubtensorStakingCallModel.unstake(model).ensureSlippageProtected()
    }

    func testClaimPassesSlippageProtection() throws {
        try SubtensorStakingCallModel.claim(hotkey: hotkey).ensureSlippageProtected()
    }
}

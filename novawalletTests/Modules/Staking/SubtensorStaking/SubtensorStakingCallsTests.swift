import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

final class SubtensorStakingCallsTests: XCTestCase {
    private let hotkey = Data(repeating: 0xAA, count: 32)
    private let hotkeyHex = String(repeating: "aa", count: 32)

    private func encodeCallHex(_ call: some RuntimeCallable) throws -> String {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()
        let context = codingFactory.createRuntimeJsonContext()
        let json = try call.toScaleCompatibleJSON(with: context.toRawContext())

        let encoder = codingFactory.createEncoder()
        try encoder.append(json: json, type: GenericType.call.name)

        return try encoder.encode().toHex()
    }

    func testAddStakeEncodesRootNetuidAndPlainU64Amount() throws {
        let call = SubtensorStakingPallet.AddStakeCall(
            hotkey: hotkey,
            netuid: 0,
            amountStaked: BigUInt(2_000_000)
        )

        let encoded = try encodeCallHex(try call.runtimeCall())

        XCTAssertEqual(encoded, "0702" + hotkeyHex + "0000" + "80841e0000000000")
    }

    func testRemoveStakeEncodesAlphaAmount() throws {
        let call = SubtensorStakingPallet.RemoveStakeCall(
            hotkey: hotkey,
            netuid: 0,
            amountUnstaked: BigUInt(1)
        )

        let encoded = try encodeCallHex(try call.runtimeCall())

        XCTAssertEqual(encoded, "0703" + hotkeyHex + "0000" + "0100000000000000")
    }

    func testAddStakeLimitEncodesLimitPriceAndAllowPartial() throws {
        let call = SubtensorStakingPallet.AddStakeLimitCall(
            hotkey: hotkey,
            netuid: 1,
            amountStaked: BigUInt(1_000_000_000),
            limitPrice: BigUInt(1_500_000_000),
            allowPartial: false
        )

        let encoded = try encodeCallHex(try call.runtimeCall())

        XCTAssertEqual(
            encoded,
            "0758" + hotkeyHex + "0100" + "00ca9a3b00000000" + "002f685900000000" + "00"
        )
    }

    func testRemoveStakeLimitEncodesLimitPriceAndAllowPartial() throws {
        let call = SubtensorStakingPallet.RemoveStakeLimitCall(
            hotkey: hotkey,
            netuid: 1,
            amountUnstaked: BigUInt(500),
            limitPrice: BigUInt(1),
            allowPartial: false
        )

        let encoded = try encodeCallHex(try call.runtimeCall())

        XCTAssertEqual(
            encoded,
            "0759" + hotkeyHex + "0100" + "f401000000000000" + "0100000000000000" + "00"
        )
    }

    func testRemoveStakeFullLimitEncodesNoneLimitPrice() throws {
        let call = SubtensorStakingPallet.RemoveStakeFullLimitCall(
            hotkey: hotkey,
            netuid: 0,
            limitPrice: nil
        )

        let encoded = try encodeCallHex(try call.runtimeCall())

        XCTAssertEqual(encoded, "0767" + hotkeyHex + "0000" + "00")
    }

    func testRemoveStakeFullLimitEncodesSomeLimitPrice() throws {
        let call = SubtensorStakingPallet.RemoveStakeFullLimitCall(
            hotkey: hotkey,
            netuid: 1,
            limitPrice: BigUInt(42)
        )

        let encoded = try encodeCallHex(try call.runtimeCall())

        XCTAssertEqual(encoded, "0767" + hotkeyHex + "0100" + "01" + "2a00000000000000")
    }

    func testAddStakeAmountAboveU64MaxThrows() {
        let call = SubtensorStakingPallet.AddStakeCall(
            hotkey: hotkey,
            netuid: 0,
            amountStaked: BigUInt(UInt64.max) + 1
        )

        XCTAssertThrowsError(try call.runtimeCall())
    }

    func testRemoveStakeFullLimitPriceAboveU64MaxThrows() {
        let call = SubtensorStakingPallet.RemoveStakeFullLimitCall(
            hotkey: hotkey,
            netuid: 0,
            limitPrice: BigUInt(UInt64.max) + 1
        )

        XCTAssertThrowsError(try call.runtimeCall())
    }

    func testAddStakeAmountAtU64MaxEncodes() throws {
        let call = SubtensorStakingPallet.AddStakeCall(
            hotkey: hotkey,
            netuid: 0,
            amountStaked: BigUInt(UInt64.max)
        )

        let encoded = try encodeCallHex(try call.runtimeCall())

        XCTAssertEqual(encoded, "0702" + hotkeyHex + "0000" + "ffffffffffffffff")
    }
}

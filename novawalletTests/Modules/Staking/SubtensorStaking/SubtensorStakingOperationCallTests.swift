import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class SubtensorStakingOperationCallTests: XCTestCase {
    private let hotkey = Data(repeating: 0xAA, count: 32)
    private let hotkeyHex = String(repeating: "aa", count: 32)
    private let groupHotkey = Data(repeating: 0xCC, count: 32)
    private let groupHotkeyHex = String(repeating: "cc", count: 32)
    private let productionBeneficiaryHex = "a4373d7b6d136b822d25106a993945f40b4cbfcbb2cfd5782888b5d938f82b1a"

    func testSubnetBuyOfTenTaoEncodesBatchAllOfNetStakeAndFeeTransferToTheProductionBeneficiary() throws {
        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: 64,
            grossTao: 10_000_000_000,
            limitPrice: 74_169_000
        )

        let expected = "0b0208" + "0758" + hotkeyHex + "4000" + "3bd3054f02000000" + "a8ba6b0400000000" + "00" +
            "050300" + productionBeneficiaryHex + "16431814"

        XCTAssertEqual(try encodeCalls(operation, feeCalculator: SubtensorNovaFeeCalculator()), [expected])
    }

    func testSubnetSellEncodesBatchAllOfRemoveStakeLimitAndFeeTransferOnTheQuotedTaoOut() throws {
        let operation = SubtensorStakingOperation.subnetSell(
            hotkey: hotkey,
            netuid: 64,
            alpha: 56_200_000_000,
            limitPrice: 73_431_000,
            quotedTaoOut: 4_145_000_000
        )

        let expected = "0b0208" + "0759" + hotkeyHex + "4000" + "00f2c7150d000000" + "d877600400000000" + "00" +
            "050300" + productionBeneficiaryHex + "ee4b5408"

        XCTAssertEqual(try encodeCalls(operation, feeCalculator: SubtensorNovaFeeCalculator()), [expected])
    }

    func testSubnetSellAllEncodesBatchAllOfFullExitsInHotkeyOrderAndOneFeeTransfer() throws {
        let operation = SubtensorStakingOperation.subnetSellAll(
            hotkeys: [hotkey, groupHotkey],
            netuid: 64,
            limitPrice: 73_431_000,
            quotedTaoOut: 4_145_000_000
        )

        let expected = "0b020c" +
            "0767" + hotkeyHex + "4000" + "01" + "d877600400000000" +
            "0767" + groupHotkeyHex + "4000" + "01" + "d877600400000000" +
            "050300" + productionBeneficiaryHex + "ee4b5408"

        XCTAssertEqual(try encodeCalls(operation, feeCalculator: SubtensorNovaFeeCalculator()), [expected])
    }

    func testSubnetSellAllWithZeroNovaFeeEncodesBatchAllOfTheFullExitsOnly() throws {
        let operation = SubtensorStakingOperation.subnetSellAll(
            hotkeys: [hotkey, groupHotkey],
            netuid: 64,
            limitPrice: 73_431_000,
            quotedTaoOut: 118
        )

        let expected = "0b0208" +
            "0767" + hotkeyHex + "4000" + "01" + "d877600400000000" +
            "0767" + groupHotkeyHex + "4000" + "01" + "d877600400000000"

        XCTAssertEqual(try encodeCalls(operation, feeCalculator: SubtensorNovaFeeCalculator()), [expected])
    }

    func testSubnetBuyWithZeroNovaFeeEncodesPlainAddStakeLimit() throws {
        let operation = SubtensorStakingOperation.subnetBuy(hotkey: hotkey, netuid: 64, grossTao: 118, limitPrice: 74_169_000)

        let addStakeLimit = "0758" + hotkeyHex + "4000" + "7600000000000000" + "a8ba6b0400000000" + "00"

        XCTAssertEqual(try encodeCalls(operation, feeCalculator: SubtensorNovaFeeCalculator()), [addStakeLimit])
    }

    func testRootStakeEncodesPlainAddStakeWithoutBeneficiary() throws {
        let operation = SubtensorStakingOperation.rootStake(hotkey: hotkey, amount: 2_000_000)

        XCTAssertEqual(
            try encodeCalls(operation, feeCalculator: SubtensorNovaFeeCalculator(beneficiary: nil)),
            ["0702" + hotkeyHex + "0000" + "80841e0000000000"]
        )
    }

    func testRootUnstakeEncodesPlainRemoveStakeWithoutBeneficiary() throws {
        let operation = SubtensorStakingOperation.rootUnstake(hotkey: hotkey, amount: 1)

        XCTAssertEqual(
            try encodeCalls(operation, feeCalculator: SubtensorNovaFeeCalculator(beneficiary: nil)),
            ["0703" + hotkeyHex + "0000" + "0100000000000000"]
        )
    }

    func testRootUnstakeAllOfOneHotkeyEncodesPlainRemoveStakeFullLimitWithNoneLimit() throws {
        let operation = SubtensorStakingOperation.rootUnstakeAll(hotkeys: [hotkey])

        XCTAssertEqual(
            try encodeCalls(operation, feeCalculator: SubtensorNovaFeeCalculator(beneficiary: nil)),
            ["0767" + hotkeyHex + "0000" + "00"]
        )
    }

    func testRootUnstakeAllOfTwoHotkeysEncodesBatchAllWithoutFeeTransfer() throws {
        let operation = SubtensorStakingOperation.rootUnstakeAll(hotkeys: [hotkey, groupHotkey])

        let expected = "0b0208" + "0767" + hotkeyHex + "0000" + "00" + "0767" + groupHotkeyHex + "0000" + "00"

        XCTAssertEqual(try encodeCalls(operation, feeCalculator: SubtensorNovaFeeCalculator()), [expected])
    }

    func testNilBeneficiaryFailsSubnetBuyClosed() {
        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: 64,
            grossTao: 10_000_000_000,
            limitPrice: 74_169_000
        )

        assertRejected(operation, beneficiary: nil, with: .novaFeeUnavailable)
    }

    func testNilBeneficiaryFailsSubnetSellClosed() {
        let operation = SubtensorStakingOperation.subnetSell(
            hotkey: hotkey,
            netuid: 64,
            alpha: 56_200_000_000,
            limitPrice: 73_431_000,
            quotedTaoOut: 4_145_000_000
        )

        assertRejected(operation, beneficiary: nil, with: .novaFeeUnavailable)
    }

    func testNilBeneficiaryFailsSubnetSellAllClosed() {
        let operation = SubtensorStakingOperation.subnetSellAll(
            hotkeys: [hotkey],
            netuid: 64,
            limitPrice: 73_431_000,
            quotedTaoOut: 4_145_000_000
        )

        assertRejected(operation, beneficiary: nil, with: .novaFeeUnavailable)
    }

    func testSubnetOrderWithoutLimitIsRejected() {
        let operation = SubtensorStakingOperation.subnetSell(
            hotkey: hotkey,
            netuid: 64,
            alpha: 56_200_000_000,
            limitPrice: 0,
            quotedTaoOut: 4_145_000_000
        )

        assertRejected(operation, beneficiary: SubtensorNovaFeeCalculator.defaultBeneficiary, with: .unprotectedSubnetOrder)
    }

    func testSubnetSellWithoutQuotedTaoOutIsRejected() {
        let operation = SubtensorStakingOperation.subnetSell(
            hotkey: hotkey,
            netuid: 64,
            alpha: 56_200_000_000,
            limitPrice: 73_431_000,
            quotedTaoOut: 0
        )

        assertRejected(operation, beneficiary: SubtensorNovaFeeCalculator.defaultBeneficiary, with: .unprotectedSubnetOrder)
    }

    func testLimitOrderOnRootNetuidIsRejected() {
        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: SubtensorStakingPallet.rootNetuid,
            grossTao: 1_000_000_000,
            limitPrice: 1_000_000_001
        )

        assertRejected(operation, beneficiary: SubtensorNovaFeeCalculator.defaultBeneficiary, with: .limitOnRootOrder)
    }

    func testEmptyHotkeyGroupIsRejected() {
        let operation = SubtensorStakingOperation.rootUnstakeAll(hotkeys: [])

        assertRejected(operation, beneficiary: SubtensorNovaFeeCalculator.defaultBeneficiary, with: .invalidHotkeyGroup)
    }

    func testDuplicatedHotkeyGroupIsRejected() {
        let operation = SubtensorStakingOperation.subnetSellAll(
            hotkeys: [hotkey, groupHotkey, hotkey],
            netuid: 64,
            limitPrice: 73_431_000,
            quotedTaoOut: 4_145_000_000
        )

        assertRejected(operation, beneficiary: SubtensorNovaFeeCalculator.defaultBeneficiary, with: .invalidHotkeyGroup)
    }

    private func encodeCalls(
        _ operation: SubtensorStakingOperation,
        feeCalculator: SubtensorNovaFeeCalculator
    ) throws -> [String] {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()
        let closure = try operation.extrinsicBuilderClosure(feeCalculator: feeCalculator)

        let builder = try closure(ExtrinsicBuilder().with(runtimeJsonContext: codingFactory.createRuntimeJsonContext()))
            .batchingCalls(with: codingFactory.metadata)

        return try builder.getCalls().map { call in
            let encoder = codingFactory.createEncoder()
            try encoder.append(json: call, type: GenericType.call.name)
            return try encoder.encode().toHex()
        }
    }

    private func assertRejected(
        _ operation: SubtensorStakingOperation,
        beneficiary: AccountId?,
        with expectedError: SubtensorStakingOperationError
    ) {
        let feeCalculator = SubtensorNovaFeeCalculator(beneficiary: beneficiary)

        XCTAssertThrowsError(try operation.extrinsicBuilderClosure(feeCalculator: feeCalculator)) { error in
            XCTAssertEqual(error as? SubtensorStakingOperationError, expectedError)
        }
    }
}

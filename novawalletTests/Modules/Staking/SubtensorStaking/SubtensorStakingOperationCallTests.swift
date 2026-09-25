import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class SubtensorStakingOperationCallTests: XCTestCase {
    private let hotkey = Data(repeating: 0xAA, count: 32)
    private let hotkeyHex = String(repeating: "aa", count: 32)
    private let beneficiary = Data(repeating: 0xBB, count: 32)
    private let beneficiaryHex = String(repeating: "bb", count: 32)

    func testSubnetBuyEncodesBatchAllOfAddStakeLimitOnNetOfFeeAndFeeTransfer() throws {
        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: 64,
            grossTao: 1_000_000_000,
            limitPrice: 7_721_671
        )

        let addStakeLimit = "0758" + hotkeyHex + "4000" + "40036d3b00000000" + "c7d2750000000000" + "00"
        let feeTransfer = "0503" + "00" + beneficiaryHex + "021bb700"

        XCTAssertEqual(try encodeCalls(operation, beneficiary: beneficiary), ["0b02" + "08" + addStakeLimit + feeTransfer])
    }

    func testSubnetSellEncodesBatchAllOfRemoveStakeLimitAndFeeTransfer() throws {
        let operation = SubtensorStakingOperation.subnetSell(
            hotkey: hotkey,
            netuid: 64,
            alpha: 500_000_000_000,
            limitPrice: 7_644_839
        )

        let removeStakeLimit = "0759" + hotkeyHex + "4000" + "0088526a74000000" + "a7a6740000000000" + "00"
        let feeTransfer = "0503" + "00" + beneficiaryHex + "eae7bb02"

        XCTAssertEqual(
            try encodeCalls(operation, beneficiary: beneficiary),
            ["0b02" + "08" + removeStakeLimit + feeTransfer]
        )
    }

    func testSubnetSellAllEncodesBatchAllOfRemoveStakeFullLimitWithSomeLimitAndFeeTransfer() throws {
        let operation = SubtensorStakingOperation.subnetSellAll(
            hotkey: hotkey,
            netuid: 64,
            alpha: 500_000_000_000,
            limitPrice: 7_644_839
        )

        let removeStakeFullLimit = "0767" + hotkeyHex + "4000" + "01" + "a7a6740000000000"
        let feeTransfer = "0503" + "00" + beneficiaryHex + "eae7bb02"

        XCTAssertEqual(
            try encodeCalls(operation, beneficiary: beneficiary),
            ["0b02" + "08" + removeStakeFullLimit + feeTransfer]
        )
    }

    func testSubnetBuyWithZeroNovaFeeEncodesPlainAddStakeLimit() throws {
        let operation = SubtensorStakingOperation.subnetBuy(hotkey: hotkey, netuid: 64, grossTao: 333, limitPrice: 7_721_671)

        let addStakeLimit = "0758" + hotkeyHex + "4000" + "4d01000000000000" + "c7d2750000000000" + "00"

        XCTAssertEqual(try encodeCalls(operation, beneficiary: beneficiary), [addStakeLimit])
    }

    func testRootStakeEncodesPlainAddStakeWithoutBeneficiary() throws {
        let operation = SubtensorStakingOperation.rootStake(hotkey: hotkey, amount: 2_000_000)

        XCTAssertEqual(try encodeCalls(operation, beneficiary: nil), ["0702" + hotkeyHex + "0000" + "80841e0000000000"])
    }

    func testRootUnstakeEncodesPlainRemoveStakeWithoutBeneficiary() throws {
        let operation = SubtensorStakingOperation.rootUnstake(hotkey: hotkey, amount: 1)

        XCTAssertEqual(try encodeCalls(operation, beneficiary: nil), ["0703" + hotkeyHex + "0000" + "0100000000000000"])
    }

    func testRootUnstakeAllEncodesRemoveStakeFullLimitWithNoneLimit() throws {
        let operation = SubtensorStakingOperation.rootUnstakeAll(hotkey: hotkey)

        XCTAssertEqual(try encodeCalls(operation, beneficiary: nil), ["0767" + hotkeyHex + "0000" + "00"])
    }

    func testClaimRootEncodesClaimRootWithHotkey() throws {
        let operation = SubtensorStakingOperation.claimRoot(hotkey: hotkey)

        XCTAssertEqual(try encodeCalls(operation, beneficiary: nil), ["0794" + hotkeyHex])
    }

    func testNilBeneficiaryFailsSubnetBuyClosed() {
        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: 64,
            grossTao: 1_000_000_000,
            limitPrice: 7_721_671
        )

        assertRejected(operation, beneficiary: nil, with: .novaFeeUnavailable)
    }

    func testNilBeneficiaryFailsSubnetSellClosed() {
        let operation = SubtensorStakingOperation.subnetSell(
            hotkey: hotkey,
            netuid: 64,
            alpha: 500_000_000_000,
            limitPrice: 7_644_839
        )

        assertRejected(operation, beneficiary: nil, with: .novaFeeUnavailable)
    }

    func testNilBeneficiaryFailsSubnetSellAllClosed() {
        let operation = SubtensorStakingOperation.subnetSellAll(
            hotkey: hotkey,
            netuid: 64,
            alpha: 500_000_000_000,
            limitPrice: 7_644_839
        )

        assertRejected(operation, beneficiary: nil, with: .novaFeeUnavailable)
    }

    func testSubnetOrderWithoutLimitIsRejected() {
        let operation = SubtensorStakingOperation.subnetSell(hotkey: hotkey, netuid: 64, alpha: 500_000_000_000, limitPrice: 0)

        assertRejected(operation, beneficiary: beneficiary, with: .unprotectedSubnetOrder)
    }

    func testLimitOrderOnRootNetuidIsRejected() {
        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: SubtensorStakingPallet.rootNetuid,
            grossTao: 1_000_000_000,
            limitPrice: 1_000_000_001
        )

        assertRejected(operation, beneficiary: beneficiary, with: .limitOnRootOrder)
    }

    private func encodeCalls(_ operation: SubtensorStakingOperation, beneficiary: AccountId?) throws -> [String] {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()
        let feeCalculator = SubtensorNovaFeeCalculator(beneficiary: beneficiary)
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

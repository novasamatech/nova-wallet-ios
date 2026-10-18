import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class SubtensorStakingOperationCallTests: XCTestCase {
    private let hotkey = Data(repeating: 0xAA, count: 32)
    private let groupHotkey = Data(repeating: 0xCC, count: 32)
    private let productionBeneficiaryHex = "5d11a510a9bef3fae089b0500483f53498b6c5e616ff0027e37c1f1e84bb1565"

    func testSubnetBuyEncodesBatchAllOfNetStakeAndFeeTransfer() throws {
        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: 64,
            grossTao: 10_000_000_000,
            limitPrice: 74_169_000,
            novaFee: try productionFee(29_910_269)
        )

        let calls = try encodeCalls(operation)

        let expected = "0b0208" + "0758" + hotkey.toHex() + "4000" + "037f435202000000" + "a8ba6b0400000000" + "00" +
            "050300" + productionBeneficiaryHex + "f6932107"
        XCTAssertEqual(calls, [expected])
    }

    func testSubnetSellEncodesRemoveStakeLimitAndFeeOnTheQuotedTaoOut() throws {
        let operation = SubtensorStakingOperation.subnetSell(
            hotkey: hotkey,
            netuid: 64,
            alpha: 56_200_000_000,
            limitPrice: 73_431_000,
            quotedTaoOut: 4_145_000_000,
            novaFee: try productionFee(12_397_806)
        )

        let calls = try encodeCalls(operation)

        let expected = "0b0208" + "0759" + hotkey.toHex() + "4000" + "00f2c7150d000000" + "d877600400000000" + "00" +
            "050300" + productionBeneficiaryHex + "bab3f402"
        XCTAssertEqual(calls, [expected])
    }

    func testSubnetSellAllEncodesFullExitsInHotkeyOrderAndOneFeeTransfer() throws {
        let operation = SubtensorStakingOperation.subnetSellGroup(
            exits: [hotkey, groupHotkey],
            partials: [],
            netuid: 64,
            limitPrice: 73_431_000,
            quotedTaoOut: 4_145_000_000,
            novaFee: try productionFee(12_397_806)
        )

        let calls = try encodeCalls(operation)

        let expected = "0b020c" +
            "0767" + hotkey.toHex() + "4000" + "01" + "d877600400000000" +
            "0767" + groupHotkey.toHex() + "4000" + "01" + "d877600400000000" +
            "050300" + productionBeneficiaryHex + "bab3f402"
        XCTAssertEqual(calls, [expected])
    }

    func testSubnetSellGroupEncodesFullExitsThenThePartialRemoveAndOneFeeTransfer() throws {
        let operation = SubtensorStakingOperation.subnetSellGroup(
            exits: [groupHotkey],
            partials: [SubtensorUnstakeSlice(hotkey: hotkey, alpha: 56_200_000_000)],
            netuid: 64,
            limitPrice: 73_431_000,
            quotedTaoOut: 4_145_000_000,
            novaFee: try productionFee(12_397_806)
        )

        let calls = try encodeCalls(operation)

        let expected = "0b020c" +
            "0767" + groupHotkey.toHex() + "4000" + "01" + "d877600400000000" +
            "0759" + hotkey.toHex() + "4000" + "00f2c7150d000000" + "d877600400000000" + "00" +
            "050300" + productionBeneficiaryHex + "bab3f402"
        XCTAssertEqual(calls, [expected])
    }

    func testSubnetBuyWithoutBeneficiaryFailsClosed() throws {
        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: 64,
            grossTao: 10_000_000_000,
            limitPrice: 74_169_000,
            novaFee: try productionFee(29_910_269)
        )

        XCTAssertThrowsError(
            try operation.extrinsicBuilderClosure(novaFeeBeneficiary: nil)
        ) { error in
            XCTAssertEqual(error as? SubtensorStakingOperationError, .novaFeeUnavailable)
        }
    }

    private func productionFee(_ amount: Balance) throws -> SubtensorNovaFee {
        SubtensorNovaFee(amount: amount, beneficiary: try XCTUnwrap(SubtensorNovaFeeCalculator.defaultBeneficiary))
    }

    private func encodeCalls(_ operation: SubtensorStakingOperation) throws -> [String] {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()
        let closure = try operation.extrinsicBuilderClosure(
            novaFeeBeneficiary: SubtensorNovaFeeCalculator.defaultBeneficiary
        )

        let builder = try closure(ExtrinsicBuilder().with(runtimeJsonContext: codingFactory.createRuntimeJsonContext()))
            .batchingCalls(with: codingFactory.metadata)

        return try builder.getCalls().map { call in
            let encoder = codingFactory.createEncoder()
            try encoder.append(json: call, type: GenericType.call.name)
            return try encoder.encode().toHex()
        }
    }
}

import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class SubtensorStakingOutcomeParserTests: XCTestCase {
    private let coldkey = Data(repeating: 0x11, count: 32)
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let blockAuthor = Data(repeating: 0x33, count: 32)
    private let beneficiary = Data(repeating: 0xBB, count: 32)
    private let netuid: UInt16 = 64
    private let extrinsicHash = "0x" + String(repeating: "07", count: 32)

    private var subnetAccount: AccountId {
        var accountId = SubtensorStakingPallet.subnetAccountPrefix!
        withUnsafeBytes(of: netuid.littleEndian) { accountId.append(contentsOf: $0) }
        accountId.append(Data(repeating: 0, count: 32 - accountId.count))
        return accountId
    }

    func testSellOutcomeSumsMainAndDustSalesExcludingAlphaFeeSaleAndFindsNovaFeeBySenderAndRecipient() throws {
        let novaFee: UInt64 = 11_467_258

        let (events, codingFactory) = try decodeEvents([
            stakeRemoved(tao: 734_304, alpha: 95_364_155, poolFee: 0),
            stakeRemoved(tao: 3_840_000_000, alpha: 500_000_000_000, poolFee: 250_000_000),
            stakeRemoved(tao: 19_500_000, alpha: 2_600_000_000, poolFee: 1_300_000),
            transfer(from: subnetAccount, to: coldkey, amount: 3_859_500_000),
            transfer(from: subnetAccount, to: blockAuthor, amount: novaFee),
            transfer(from: coldkey, to: beneficiary, amount: novaFee),
            alphaFeePaid(alphaFee: 95_364_155, taoAmount: 734_304)
        ])

        let outcome = try makeParser(codingFactory: codingFactory).parse(
            events: events.filter { SubtensorStakingEventMatcher().match(event: $0, using: codingFactory) },
            for: .subnetSell(hotkey: hotkey, netuid: netuid, alpha: 500_000_000_000, limitPrice: 7_644_839),
            extrinsicHash: extrinsicHash
        )

        let expected = SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: 3_859_500_000, alpha: 502_600_000_000, netuid: netuid),
            claimedTao: nil,
            novaFeePaid: BigUInt(novaFee),
            alphaFeePaid: 95_364_155,
            extrinsicHash: extrinsicHash
        )

        XCTAssertEqual(outcome, expected)
    }

    func testBuyOutcomeReportsClampedStakeAddedAndOnlyTheBeneficiaryTransferAsNovaFee() throws {
        let (events, codingFactory) = try decodeEvents([
            transfer(from: coldkey, to: subnetAccount, amount: 996_999_500),
            stakeAdded(tao: 996_999_500, alpha: 129_000_000_000, poolFee: 498_000),
            transfer(from: coldkey, to: beneficiary, amount: 3_000_000)
        ])

        let outcome = try makeParser(codingFactory: codingFactory).parse(
            events: events,
            for: .subnetBuy(hotkey: hotkey, netuid: netuid, grossTao: 1_000_000_000, limitPrice: 7_721_671),
            extrinsicHash: extrinsicHash
        )

        let expected = SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: 996_999_500, alpha: 129_000_000_000, netuid: netuid),
            claimedTao: nil,
            novaFeePaid: 3_000_000,
            alphaFeePaid: nil,
            extrinsicHash: extrinsicHash
        )

        XCTAssertEqual(outcome, expected)
    }

    func testInterruptedBatchFailsWithTheInnerDispatchError() throws {
        let (events, codingFactory) = try decodeEvents([
            stakeAdded(tao: 996_999_500, alpha: 129_000_000_000, poolFee: 498_000),
            batchInterrupted(itemIndex: 1, palletIndex: 5, errorIndex: 4)
        ])

        let parser = makeParser(codingFactory: codingFactory)
        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: netuid,
            grossTao: 1_000_000_000,
            limitPrice: 7_721_671
        )

        XCTAssertThrowsError(try parser.parse(events: events, for: operation, extrinsicHash: extrinsicHash)) { error in
            guard case let .module(moduleError) = error as? DispatchCallError else {
                return XCTFail("unexpected error \(error)")
            }

            XCTAssertEqual(moduleError.display.moduleName, "Balances")
            XCTAssertEqual(moduleError.display.errorName, "Expendability")
        }
    }

    private func makeParser(codingFactory: RuntimeCoderFactoryProtocol) -> SubtensorStakingOutcomeParser {
        SubtensorStakingOutcomeParser(coldkey: coldkey, novaFeeBeneficiary: beneficiary, codingFactory: codingFactory)
    }

    private func decodeEvents(_ eventsHex: [String]) throws -> ([Event], RuntimeCoderFactoryProtocol) {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let entry = try XCTUnwrap(codingFactory.metadata.getStorageMetadata(for: SystemPallet.eventsPath))

        let recordsHex = compact(eventsHex.count) + eventsHex.map { "00" + "00000000" + $0 + "00" }.joined()
        let decoder = try codingFactory.createDecoder(from: Data(hexString: recordsHex))
        let json = try decoder.read(type: entry.type.typeName)

        let records = try json.map(
            to: [EventRecord].self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        )

        return (records.map(\.event), codingFactory)
    }

    private func stakeAdded(tao: UInt64, alpha: UInt64, poolFee: UInt64) -> String {
        "0702" + coldkey.toHex() + hotkey.toHex() + le(tao) + le(alpha) + le(netuid) + le(poolFee)
    }

    private func stakeRemoved(tao: UInt64, alpha: UInt64, poolFee: UInt64) -> String {
        "0703" + coldkey.toHex() + hotkey.toHex() + le(tao) + le(alpha) + le(netuid) + le(poolFee)
    }

    private func alphaFeePaid(alphaFee: UInt64, taoAmount: UInt64) -> String {
        "0780" + coldkey.toHex() + le(netuid) + le(alphaFee) + le(taoAmount)
    }

    private func transfer(from sender: AccountId, to receiver: AccountId, amount: UInt64) -> String {
        "0502" + sender.toHex() + receiver.toHex() + le(amount)
    }

    private func batchInterrupted(itemIndex: UInt32, palletIndex: UInt8, errorIndex: UInt8) -> String {
        "0b00" + le(itemIndex) + "03" + le(palletIndex) + le(errorIndex) + "000000"
    }

    private func le<T: FixedWidthInteger>(_ value: T) -> String {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }.toHex()
    }

    private func compact(_ value: Int) -> String {
        le(UInt8(value << 2))
    }
}

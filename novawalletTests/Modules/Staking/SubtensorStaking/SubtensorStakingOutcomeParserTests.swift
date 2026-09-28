import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class SubtensorStakingOutcomeParserTests: XCTestCase {
    private let coldkey = Data(repeating: 0x11, count: 32)
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let groupHotkey = Data(repeating: 0x44, count: 32)
    private let foreignHotkey = Data(repeating: 0x55, count: 32)
    private let blockAuthor = Data(repeating: 0x33, count: 32)
    private let beneficiary = Data(repeating: 0xBB, count: 32)
    private let netuid: UInt16 = 64
    private let extrinsicHash = "0x" + String(repeating: "07", count: 32)
    private let blockHash = "0x" + String(repeating: "08", count: 32)

    private var subnetAccount: AccountId {
        var accountId = SubtensorStakingPallet.subnetAccountPrefix!
        withUnsafeBytes(of: netuid.littleEndian) { accountId.append(contentsOf: $0) }
        accountId.append(Data(repeating: 0, count: 32 - accountId.count))
        return accountId
    }

    func testSellOutcomeCountsThePoolFeeInTheExecutedAlpha() throws {
        let (events, codingFactory) = try decodeEvents([
            stakeRemoved(hotkey: hotkey, tao: 4_145_000_000, alpha: 56_171_700_618, poolFee: 28_299_382),
            transfer(from: subnetAccount, to: coldkey, amount: 4_145_000_000),
            transfer(from: coldkey, to: beneficiary, amount: 34_935_547),
            transactionFeePaid(payee: coldkey, actualFee: 1_500_000)
        ])

        let outcome = try makeParser(codingFactory: codingFactory).parse(
            events: events.filter { SubtensorStakingEventMatcher().match(event: $0, using: codingFactory) },
            for: .subnetSell(
                hotkey: hotkey,
                netuid: netuid,
                alpha: 56_200_000_000,
                limitPrice: 73_431_000,
                quotedTaoOut: 4_145_000_000
            ),
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        )

        let expected = SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: 4_145_000_000, alpha: 56_200_000_000, netuid: netuid),
            novaFeePaid: 34_935_547,
            alphaFeePaid: nil,
            networkFeePaid: 1_500_000,
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        )

        XCTAssertEqual(outcome, expected)
    }

    func testSellOutcomeExcludesAlphaFeeSaleFindsNovaFeeBySenderAndPrefersTheAlphaNetworkFee() throws {
        let novaFee: UInt64 = 11_467_258

        let (events, codingFactory) = try decodeEvents([
            stakeRemoved(hotkey: hotkey, tao: 734_304, alpha: 95_364_155, poolFee: 0),
            stakeRemoved(hotkey: hotkey, tao: 3_840_000_000, alpha: 499_750_000_000, poolFee: 250_000_000),
            stakeRemoved(hotkey: hotkey, tao: 19_500_000, alpha: 2_598_700_000, poolFee: 1_300_000),
            transfer(from: subnetAccount, to: coldkey, amount: 3_859_500_000),
            transfer(from: subnetAccount, to: blockAuthor, amount: novaFee),
            transfer(from: coldkey, to: beneficiary, amount: novaFee),
            alphaFeePaid(alphaFee: 95_364_155, taoAmount: 734_304),
            transactionFeePaid(payee: coldkey, actualFee: 700_000)
        ])

        let outcome = try makeParser(codingFactory: codingFactory).parse(
            events: events.filter { SubtensorStakingEventMatcher().match(event: $0, using: codingFactory) },
            for: .subnetSell(
                hotkey: hotkey,
                netuid: netuid,
                alpha: 500_000_000_000,
                limitPrice: 7_644_839,
                quotedTaoOut: 3_859_500_000
            ),
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        )

        let expected = SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: 3_859_500_000, alpha: 502_600_000_000, netuid: netuid),
            novaFeePaid: BigUInt(novaFee),
            alphaFeePaid: 95_364_155,
            networkFeePaid: 734_304,
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        )

        XCTAssertEqual(outcome, expected)
    }

    func testGroupExitOutcomeSumsEveryHotkeyOfTheGroupAndNothingElse() throws {
        let (events, codingFactory) = try decodeEvents([
            stakeRemoved(hotkey: hotkey, tao: 3_000_000_000, alpha: 40_979_874_380, poolFee: 20_125_620),
            stakeRemoved(hotkey: groupHotkey, tao: 1_145_000_000, alpha: 15_191_826_238, poolFee: 8_173_762),
            stakeRemoved(hotkey: foreignHotkey, tao: 500_000_000, alpha: 6_700_000_000, poolFee: 3_000_000)
        ])

        let outcome = try makeParser(codingFactory: codingFactory).parse(
            events: events,
            for: .subnetSellAll(
                hotkeys: [hotkey, groupHotkey],
                netuid: netuid,
                limitPrice: 73_431_000,
                quotedTaoOut: 4_145_000_000
            ),
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        )

        XCTAssertEqual(
            outcome.executed,
            SubtensorExecutedAmounts(tao: 4_145_000_000, alpha: 56_200_000_000, netuid: netuid)
        )
    }

    func testBuyOutcomeReportsStakeAddedOnlyTheBeneficiaryTransferAsNovaFeeAndTheSignerTransactionFee() throws {
        let (events, codingFactory) = try decodeEvents([
            transfer(from: coldkey, to: subnetAccount, amount: 9_915_716_411),
            stakeAdded(tao: 9_915_716_411, alpha: 133_000_000_000, poolFee: 4_993_036),
            transfer(from: coldkey, to: beneficiary, amount: 84_283_589),
            transactionFeePaid(payee: coldkey, actualFee: 1_500_000)
        ])

        let outcome = try makeParser(codingFactory: codingFactory).parse(
            events: events,
            for: .subnetBuy(hotkey: hotkey, netuid: netuid, grossTao: 10_000_000_000, limitPrice: 74_169_000),
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        )

        let expected = SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: 9_915_716_411, alpha: 133_000_000_000, netuid: netuid),
            novaFeePaid: 84_283_589,
            alphaFeePaid: nil,
            networkFeePaid: 1_500_000,
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
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

        XCTAssertThrowsError(
            try parser.parse(events: events, for: operation, extrinsicHash: extrinsicHash, blockHash: blockHash)
        ) { error in
            guard case let .module(moduleError) = error as? DispatchCallError else {
                return XCTFail("unexpected error \(error)")
            }

            XCTAssertEqual(moduleError.display.moduleName, "Balances")
            XCTAssertEqual(moduleError.display.errorName, "Expendability")
        }
    }

    func testTokenDispatchErrorDecodesToTheTokenModuleAndReasonTheMapperMatches() throws {
        let (events, codingFactory) = try decodeEvents([
            batchInterrupted(itemIndex: 1, tokenErrorIndex: 8)
        ])

        let parser = makeParser(codingFactory: codingFactory)
        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: netuid,
            grossTao: 10_000_000_000,
            limitPrice: 74_169_000
        )

        XCTAssertThrowsError(
            try parser.parse(events: events, for: operation, extrinsicHash: extrinsicHash, blockHash: blockHash)
        ) { error in
            guard case let .other(otherError) = error as? DispatchCallError else {
                return XCTFail("unexpected error \(error)")
            }

            XCTAssertEqual(otherError.module, "Token")
            XCTAssertEqual(otherError.reason, "NotExpendable")
            XCTAssertEqual(
                SubtensorStakingErrorMapper().mapSubmission(error: error) as? SubtensorStakingSubmissionError,
                .notEnoughBalanceToStake
            )
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

    private func stakeRemoved(hotkey: AccountId, tao: UInt64, alpha: UInt64, poolFee: UInt64) -> String {
        "0703" + coldkey.toHex() + hotkey.toHex() + le(tao) + le(alpha) + le(netuid) + le(poolFee)
    }

    private func alphaFeePaid(alphaFee: UInt64, taoAmount: UInt64) -> String {
        "0780" + coldkey.toHex() + le(netuid) + le(alphaFee) + le(taoAmount)
    }

    private func transactionFeePaid(payee: AccountId, actualFee: UInt64) -> String {
        "0600" + payee.toHex() + le(actualFee) + le(UInt64(0))
    }

    private func transfer(from sender: AccountId, to receiver: AccountId, amount: UInt64) -> String {
        "0502" + sender.toHex() + receiver.toHex() + le(amount)
    }

    private func batchInterrupted(itemIndex: UInt32, palletIndex: UInt8, errorIndex: UInt8) -> String {
        "0b00" + le(itemIndex) + "03" + le(palletIndex) + le(errorIndex) + "000000"
    }

    private func batchInterrupted(itemIndex: UInt32, tokenErrorIndex: UInt8) -> String {
        "0b00" + le(itemIndex) + "07" + le(tokenErrorIndex)
    }

    private func le<T: FixedWidthInteger>(_ value: T) -> String {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }.toHex()
    }

    private func compact(_ value: Int) -> String {
        le(UInt8(value << 2))
    }
}

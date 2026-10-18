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
    private let blockHash = "0x" + String(repeating: "08", count: 32)

    func testSellOutcomeExcludesTheAlphaFeeSaleAndFindsTheNovaFeeBySender() throws {
        let events = [
            stakeRemoved(tao: 734_304, alpha: 95_364_155, poolFee: 0),
            stakeRemoved(tao: 3_840_000_000, alpha: 499_750_000_000, poolFee: 250_000_000),
            stakeRemoved(tao: 19_500_000, alpha: 2_598_700_000, poolFee: 1_300_000),
            SubtensorFixtureDecoding.transferEvent(from: subnetAccount(), to: coldkey, amount: 3_859_500_000),
            SubtensorFixtureDecoding.transferEvent(from: subnetAccount(), to: blockAuthor, amount: 11_467_258),
            SubtensorFixtureDecoding.transferEvent(from: coldkey, to: beneficiary, amount: 11_467_258),
            SubtensorFixtureDecoding.alphaFeePaidEvent(
                coldkey: coldkey,
                netuid: netuid,
                alphaFee: 95_364_155,
                taoAmount: 734_304
            ),
            SubtensorFixtureDecoding.transactionFeePaidEvent(who: coldkey, actualFee: 700_000)
        ]
        let operation = SubtensorStakingOperation.subnetSell(
            hotkey: hotkey,
            netuid: netuid,
            alpha: 500_000_000_000,
            limitPrice: 7_644_839,
            quotedTaoOut: 3_859_500_000,
            novaFee: SubtensorNovaFee(amount: 11_467_258, beneficiary: beneficiary)
        )

        let outcome = try parse(events, for: operation)

        XCTAssertEqual(outcome, SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: 3_859_500_000, alpha: 502_600_000_000, netuid: netuid),
            novaFeePaid: 11_467_258,
            alphaFeePaid: 95_364_155,
            networkFeePaid: 734_304,
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        ))
    }

    func testBuyOutcomeReportsStakeAddedNovaFeeAndNetworkFee() throws {
        let events = [
            SubtensorFixtureDecoding.transferEvent(from: coldkey, to: subnetAccount(), amount: 9_915_716_411),
            stakeAdded(tao: 9_915_716_411, alpha: 133_000_000_000, poolFee: 4_993_036),
            SubtensorFixtureDecoding.transferEvent(from: coldkey, to: beneficiary, amount: 84_283_589),
            SubtensorFixtureDecoding.transactionFeePaidEvent(who: coldkey, actualFee: 1_500_000)
        ]
        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: netuid,
            grossTao: 10_000_000_000,
            limitPrice: 74_169_000,
            novaFee: SubtensorNovaFee(amount: 84_283_589, beneficiary: beneficiary)
        )

        let outcome = try parse(events, for: operation)

        XCTAssertEqual(outcome, SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: 9_915_716_411, alpha: 133_000_000_000, netuid: netuid),
            novaFeePaid: 84_283_589,
            alphaFeePaid: nil,
            networkFeePaid: 1_500_000,
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        ))
    }

    private func parse(
        _ eventsHex: [String],
        for operation: SubtensorStakingOperation
    ) throws -> SubtensorStakingOperationOutcome {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()
        let events = try SubtensorFixtureDecoding.decodeEvents(eventsHex, codingFactory: codingFactory)
        let parser = SubtensorStakingOutcomeParser(
            coldkey: coldkey,
            novaFeeBeneficiary: beneficiary,
            codingFactory: codingFactory
        )

        return parser.parse(events: events, for: operation, extrinsicHash: extrinsicHash, blockHash: blockHash)
    }

    private func subnetAccount() -> AccountId {
        var accountId = SubtensorStakingPallet.subnetAccountPrefix!
        withUnsafeBytes(of: netuid.littleEndian) { accountId.append(contentsOf: $0) }
        accountId.append(Data(repeating: 0, count: 32 - accountId.count))
        return accountId
    }

    private func stakeAdded(tao: UInt64, alpha: UInt64, poolFee: UInt64) -> String {
        SubtensorFixtureDecoding.stakeAddedEvent(
            coldkey: coldkey,
            hotkey: hotkey,
            netuid: netuid,
            tao: tao,
            alpha: alpha,
            poolFee: poolFee
        )
    }

    private func stakeRemoved(tao: UInt64, alpha: UInt64, poolFee: UInt64) -> String {
        SubtensorFixtureDecoding.stakeRemovedEvent(
            coldkey: coldkey,
            hotkey: hotkey,
            netuid: netuid,
            tao: tao,
            alpha: alpha,
            poolFee: poolFee
        )
    }
}

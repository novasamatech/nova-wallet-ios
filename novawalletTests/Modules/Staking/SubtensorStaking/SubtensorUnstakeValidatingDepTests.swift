import BigInt
@testable import novawallet
import XCTest

final class SubtensorUnstakeValidatingDepTests: XCTestCase {
    private let accountId = Data(repeating: 0x11, count: 32)
    private let primaryHotkey = Data(repeating: 0x22, count: 32)
    private let secondHotkey = Data(repeating: 0x33, count: 32)

    private func makePreflight(hotkeyOwner: AccountId? = nil) -> SubtensorStakingPreflight {
        SubtensorStakingPreflight(
            hotkeyExists: true,
            subnetExists: true,
            subtokenEnabled: true,
            hasColdkeySwapAnnouncement: false,
            isSafeModeActive: false,
            stakeAvailability: nil,
            rootStakeUnlockInterval: 7200,
            lastStakeBlock: nil,
            minStake: 2_000_000,
            effectiveNominatorMinStake: 20_000_000,
            rootClaimableThreshold: 500_000,
            delegateTake: 11796,
            hotkeyOwner: hotkeyOwner
        )
    }

    private func makeLatestSellQuote() -> SubtensorTradeQuote {
        let quote = SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: 64, direction: .unstake(alphaIn: 56_200_000_000)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: 4_145_000_000,
                alphaAmount: 56_171_700_618,
                taoFee: 0,
                alphaFee: 28_299_382,
                taoSlippage: 0,
                alphaSlippage: 0
            ),
            spotPrice: 73_800_000,
            feeRate: 33
        )

        return SubtensorTradeQuote(
            quote: quote,
            amountIn: 56_200_000_000,
            novaFee: SubtensorNovaFee(amount: 34_935_547, beneficiary: Data(repeating: 0xBB, count: 32)),
            expectedOut: 4_110_064_453,
            swapMinimumOut: 4_124_744_148,
            minimumOut: 4_089_808_601,
            limitPrice: 73_431_000
        )
    }

    private func makeDep(
        netuid: UInt16 = SubtensorStakingPallet.rootNetuid,
        amount: Balance = 1_000_000_000,
        availability: SubtensorStakingPallet.StakeAvailability? = nil,
        exitHotkeys: [AccountId]? = nil,
        preflight: SubtensorStakingPreflight? = nil,
        holds: [AccountId: SubtensorRootHold]? = nil,
        currentBlock: BlockNumber? = 100_000,
        quoteContext: SubtensorQuoteValidatingContext? = nil
    ) -> SubtensorUnstakeValidatingDep {
        SubtensorUnstakeValidatingDep(
            netuid: netuid,
            accountId: accountId,
            amount: amount,
            positionAlpha: 100_000_000_000,
            availability: availability,
            exitHotkeys: exitHotkeys,
            balance: nil,
            fee: nil,
            existentialDeposit: 500,
            preflight: preflight ?? makePreflight(),
            holds: holds,
            currentBlock: currentBlock,
            blockTime: 12000,
            assetDisplayInfo: AssetBalanceDisplayInfo.units(for: 9),
            syncFailed: false,
            onFeeRefresh: {},
            onPreflightRefresh: {},
            onPositionsRefresh: {},
            onUnstakeAll: nil,
            quoteContext: quoteContext
        )
    }

    private func makeSellDep(acknowledgedLimit: Balance?) -> SubtensorUnstakeValidatingDep {
        makeDep(
            netuid: 64,
            amount: 56_200_000_000,
            quoteContext: SubtensorQuoteValidatingContext(
                latestQuote: makeLatestSellQuote(),
                acknowledgedLimit: acknowledgedLimit,
                tradesUnavailable: false,
                onQuoteRefresh: {}
            )
        )
    }

    func testSubnetSellIsBatched() {
        XCTAssertTrue(makeSellDep(acknowledgedLimit: 73_431_000).isBatched)
    }

    func testSingleHotkeyRootUnstakeIsNotBatched() {
        XCTAssertFalse(makeDep(exitHotkeys: [primaryHotkey]).isBatched)
    }

    func testRootGroupExitIsBatched() {
        XCTAssertTrue(makeDep(exitHotkeys: [primaryHotkey, secondHotkey]).isBatched)
    }

    func testSubnetSellPlanUsesTheGuaranteedSwapOutputAndTheAcknowledgedLimit() throws {
        let input = try XCTUnwrap(makeSellDep(acknowledgedLimit: 73_300_000).sellPlanInput)

        XCTAssertEqual(input.requestedAlpha, 56_200_000_000)
        XCTAssertEqual(input.minimumTaoOut, 4_124_744_148)
        XCTAssertEqual(input.sellLimitPrice, 73_300_000)
        XCTAssertEqual(input.minStake, 2_000_000)
        XCTAssertEqual(input.nominatorMinStake, 20_000_000)
    }

    func testSubnetSellPlanIsUndefinedWithoutAnAcknowledgedLimit() {
        XCTAssertNil(makeSellDep(acknowledgedLimit: nil).sellPlanInput)
    }

    func testRootSellPlanTakesTheAmountAtParity() throws {
        let input = try XCTUnwrap(makeDep().sellPlanInput)

        XCTAssertEqual(input.minimumTaoOut, 1_000_000_000)
        XCTAssertEqual(input.sellLimitPrice, SubtensorStakingPallet.alphaPriceScale)
    }

    func testSellPlanTreatsAMissingAvailabilityAsUnlocked() throws {
        let input = try XCTUnwrap(makeDep().sellPlanInput)

        XCTAssertEqual(input.availability.available, 100_000_000_000)
    }

    func testSellPlanKeepsThePinnedAvailability() throws {
        let availability = SubtensorStakingPallet.StakeAvailability(
            total: 100_000_000_000,
            locked: 40_000_000_000,
            available: 60_000_000_000
        )

        let input = try XCTUnwrap(makeDep(availability: availability).sellPlanInput)

        XCTAssertEqual(input.availability, availability)
    }

    func testSellPlanRecognisesTheOwnHotkeyFromThePreflightOwner() throws {
        let input = try XCTUnwrap(makeDep(preflight: makePreflight(hotkeyOwner: accountId)).sellPlanInput)

        XCTAssertTrue(input.isOwnHotkey)
    }

    func testGroupExitHoldsFollowEveryMember() {
        let primaryHold = SubtensorRootHold(interval: 7200, lastStakeBlock: 90000)
        let secondHold = SubtensorRootHold(interval: 7200, lastStakeBlock: 95000)

        let dep = makeDep(
            exitHotkeys: [primaryHotkey, secondHotkey],
            holds: [primaryHotkey: primaryHold, secondHotkey: secondHold]
        )

        XCTAssertEqual(dep.groupExitHolds, [primaryHold, secondHold])
    }

    func testGroupExitMemberWithoutHoldDataIsHeldFromTheCurrentBlock() {
        let dep = makeDep(
            exitHotkeys: [primaryHotkey, secondHotkey],
            holds: [primaryHotkey: SubtensorRootHold(interval: 7200, lastStakeBlock: 90000)]
        )

        XCTAssertEqual(dep.groupExitHolds?.last, SubtensorRootHold(interval: 7200, lastStakeBlock: 100_000))
    }

    func testSingleHotkeyExitChecksThePreflightHoldInstead() {
        XCTAssertNil(makeDep(exitHotkeys: [primaryHotkey]).groupExitHolds)
    }
}

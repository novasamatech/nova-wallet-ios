import BigInt
@testable import novawallet
import XCTest

final class SubtensorAmountPolicyTests: XCTestCase {
    private let minStake: Balance = 2_000_000
    private let spotPrice: Balance = 7_700_000
    private let sellLimitPrice: Balance = 7_644_839
    private let requestedAlpha: Balance = 400_000_000_000
    private let dustRemainder: Balance = 2_600_000_000

    private var nominatorMinStake: Balance {
        SubtensorStakingPreflight.effectiveNominatorMinStake(minStake: minStake, factor: 10_000_000)
    }

    func testMaxBuyOrStakeRetainsNetworkFeeAndFeeReserve() {
        let maxAmount = SubtensorAmountPolicy.maxBuyOrStake(transferable: 1_000_000_000, networkFee: 939_721)

        XCTAssertEqual(maxAmount, 989_060_279)
    }

    func testBuyMaxKeepsTheFeeReserveAndStakesItNetOfTheNovaFee() throws {
        let maxAmount = SubtensorAmountPolicy.maxBuyOrStake(transferable: 48_200_000_000, networkFee: 1_500_000)
        let novaFee = try XCTUnwrap(SubtensorNovaFeeCalculator().buyFee(grossTao: maxAmount))

        XCTAssertEqual(maxAmount, 48_188_500_000)
        XCTAssertEqual(novaFee.amount, 406_149_975)
        XCTAssertEqual(maxAmount - novaFee.amount, 47_782_350_025)
    }

    func testMaxBuyOrStakeFloorsAtZero() {
        let maxAmount = SubtensorAmountPolicy.maxBuyOrStake(transferable: 10_500_000, networkFee: 939_721)

        XCTAssertEqual(maxAmount, 0)
    }

    func testBatchedSellIsRefusedWithoutFreeTaoForNetworkFeeAndExistentialDeposit() {
        let canPay = SubtensorAmountPolicy.canPayBatchedSell(
            transferable: 734_803,
            networkFee: 734_304,
            existentialDeposit: 500
        )

        XCTAssertFalse(canPay)
    }

    func testBatchedSellIsAllowedWithFreeTaoForNetworkFeeAndExistentialDeposit() {
        let canPay = SubtensorAmountPolicy.canPayBatchedSell(
            transferable: 734_804,
            networkFee: 734_304,
            existentialDeposit: 500
        )

        XCTAssertTrue(canPay)
    }

    func testMaxSellIsCappedByAvailableAlpha() {
        let maxSell = SubtensorAmountPolicy.maxSell(
            positionAlpha: 500_000_000_000,
            availability: availability(total: 500_000_000_000, locked: 120_000_000_000)
        )

        XCTAssertEqual(maxSell, 380_000_000_000)
    }

    func testSellAboveAvailableAlphaExceedsAvailable() {
        let position = requestedAlpha + dustRemainder

        let plan = sellPlan(
            requestedAlpha: requestedAlpha,
            positionAlpha: position,
            availability: availability(total: position, locked: dustRemainder + 1)
        )

        XCTAssertEqual(plan, .exceedsAvailable)
    }

    func testSellOfWholeFullyAvailablePositionIsSellAll() {
        let plan = sellPlan(
            requestedAlpha: requestedAlpha,
            positionAlpha: requestedAlpha,
            availability: availability(total: requestedAlpha, locked: 0)
        )

        XCTAssertEqual(plan, .sellAll)
    }

    func testPartialSellWithLimitGuaranteedOutBelowMinStakeIsBelowMinimumOut() throws {
        let smallAlpha: Balance = 261_600_000
        let position = smallAlpha + 100_000_000_000

        let plan = try sellPlan(
            requestedAlpha: smallAlpha,
            positionAlpha: position,
            availability: availability(total: position, locked: 0),
            minimumTaoOut: SubtensorNovaFeeCalculator.minimumTaoOut(alpha: smallAlpha, limitPrice: sellLimitPrice)
        )

        XCTAssertEqual(plan, .belowMinimumOut)
    }

    func testRemainderWorthNominatorMinimumAtSpotButNotAtSellLimitIsSwept() {
        let position = requestedAlpha + dustRemainder

        let plan = sellPlan(
            requestedAlpha: requestedAlpha,
            positionAlpha: position,
            availability: availability(total: position, locked: 0)
        )

        XCTAssertGreaterThanOrEqual(dustRemainder * spotPrice / SubtensorStakingPallet.alphaPriceScale, nominatorMinStake)
        XCTAssertEqual(plan, .remainderWouldBeSwept)
    }

    func testLockedDustRemainderWouldBeErased() {
        let position = requestedAlpha + dustRemainder

        let plan = sellPlan(
            requestedAlpha: requestedAlpha,
            positionAlpha: position,
            availability: availability(total: position, locked: 1)
        )

        XCTAssertEqual(plan, .remainderWouldBeErased)
    }

    func testRemainderAboveNominatorMinimumIsPartial() {
        let position = requestedAlpha + 100_000_000_000

        let plan = sellPlan(
            requestedAlpha: requestedAlpha,
            positionAlpha: position,
            availability: availability(total: position, locked: 0)
        )

        XCTAssertEqual(plan, .partial)
    }

    func testOwnHotkeyDustRemainderIsExemptFromSweep() {
        let position = requestedAlpha + dustRemainder

        let plan = sellPlan(
            requestedAlpha: requestedAlpha,
            positionAlpha: position,
            availability: availability(total: position, locked: 1),
            isOwnHotkey: true
        )

        XCTAssertEqual(plan, .partial)
    }

    private func availability(total: Balance, locked: Balance) -> SubtensorStakingPallet.StakeAvailability {
        SubtensorStakingPallet.StakeAvailability(total: total, locked: locked, available: total - locked)
    }

    private func sellPlan(
        requestedAlpha: Balance,
        positionAlpha: Balance,
        availability: SubtensorStakingPallet.StakeAvailability,
        minimumTaoOut: Balance? = nil,
        isOwnHotkey: Bool = false
    ) -> SubtensorSellPlan {
        let input = SubtensorSellPlanInput(
            requestedAlpha: requestedAlpha,
            positionAlpha: positionAlpha,
            availability: availability,
            minimumTaoOut: minimumTaoOut ?? requestedAlpha * sellLimitPrice / SubtensorStakingPallet.alphaPriceScale,
            sellLimitPrice: sellLimitPrice,
            isOwnHotkey: isOwnHotkey,
            minStake: minStake,
            nominatorMinStake: nominatorMinStake
        )

        return SubtensorAmountPolicy.sellPlan(for: input)
    }
}

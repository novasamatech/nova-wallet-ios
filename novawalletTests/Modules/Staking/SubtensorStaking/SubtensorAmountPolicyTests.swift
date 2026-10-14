import BigInt
@testable import novawallet
import XCTest

final class SubtensorAmountPolicyTests: XCTestCase {
    private let requestedAlpha: Balance = 400_000_000_000
    private let dustRemainder: Balance = 2_600_000_000

    func testMaxBuyKeepsTheNetworkFeeAndFeeReserve() {
        let maxAmount = SubtensorAmountPolicy.maxBuyOrStake(transferable: 1_000_000_000, networkFee: 939_721)

        XCTAssertEqual(maxAmount, 989_060_279)
    }

    func testSellLeavingRemainderAboveNominatorMinimumIsPartial() {
        let plan = performSellPlan(positionAlpha: requestedAlpha + 100_000_000_000)

        XCTAssertEqual(plan, .partial)
    }

    func testSellLeavingDustRemainderWouldBeSwept() {
        let plan = performSellPlan(positionAlpha: requestedAlpha + dustRemainder)

        XCTAssertEqual(plan, .remainderWouldBeSwept)
    }

    func testSellAboveAvailableAlphaExceedsAvailable() {
        let plan = performSellPlan(positionAlpha: requestedAlpha + dustRemainder, lockedAlpha: dustRemainder + 1)

        XCTAssertEqual(plan, .exceedsAvailable)
    }

    private func performSellPlan(positionAlpha: Balance, lockedAlpha: Balance = 0) -> SubtensorSellPlan {
        let minStake: Balance = 2_000_000
        let sellLimitPrice: Balance = 7_644_839

        let input = SubtensorSellPlanInput(
            requestedAlpha: requestedAlpha,
            positionAlpha: positionAlpha,
            availability: SubtensorStakingPallet.StakeAvailability(
                total: positionAlpha,
                locked: lockedAlpha,
                available: positionAlpha - lockedAlpha
            ),
            minimumTaoOut: requestedAlpha * sellLimitPrice / SubtensorStakingPallet.alphaPriceScale,
            sellLimitPrice: sellLimitPrice,
            isOwnHotkey: false,
            minStake: minStake,
            nominatorMinStake: SubtensorStakingPreflight.effectiveNominatorMinStake(
                minStake: minStake,
                factor: 10_000_000
            )
        )

        return SubtensorAmountPolicy.sellPlan(for: input)
    }
}

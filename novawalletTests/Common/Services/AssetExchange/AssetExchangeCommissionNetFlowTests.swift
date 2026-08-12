import XCTest
@testable import novawallet
import BigInt

final class AssetExchangeCommissionNetFlowTests: XCTestCase {
    func testNoCommissionLeavesAmountsUntouched() {
        let flow = AssetExchangeCommissionNetFlow(
            operations: [CommissionTestFixtures.metaOperation(amountIn: 100, amountOut: 200)],
            commission: nil
        )

        XCTAssertEqual(flow.netAmountOut(at: 0), 200)
        XCTAssertEqual(flow.netFinalAmountOut, 200)
    }

    func testDeductionAppliesAtChargingOperation() {
        let flow = AssetExchangeCommissionNetFlow(
            operations: [CommissionTestFixtures.metaOperation(amountIn: 1_000, amountOut: 2_000)],
            commission: CommissionTestFixtures.makeCommission(chargingOperationIndex: 0, estimatedAmount: 17)
        )

        XCTAssertEqual(flow.netAmountOut(at: 0), 1_983)
        XCTAssertEqual(flow.netFinalAmountOut, 1_983)
    }

    func testDeductionPropagatesThroughLaterOperations() {
        let flow = AssetExchangeCommissionNetFlow(
            operations: [
                CommissionTestFixtures.metaOperation(amountIn: 1_000, amountOut: 2_000),
                CommissionTestFixtures.metaOperation(amountIn: 2_000, amountOut: 1_000)
            ],
            commission: CommissionTestFixtures.makeCommission(chargingOperationIndex: 0, estimatedAmount: 100)
        )

        XCTAssertEqual(flow.netAmountOut(at: 0), 1_900)
        XCTAssertEqual(flow.netAmountIn(at: 1), 1_900)
        XCTAssertEqual(flow.netFinalAmountOut, 950)
    }

    func testCrossChainCarriesTheDeductionOneToOne() {
        let flow = AssetExchangeCommissionNetFlow(
            operations: [
                CommissionTestFixtures.metaOperation(amountIn: 1_000_000_000_000, amountOut: 1_009_000_000_000),
                CommissionTestFixtures.metaOperation(
                    amountIn: 1_009_000_000_000,
                    amountOut: 1_008_500_000_000,
                    label: .transfer
                )
            ],
            commission: CommissionTestFixtures.makeCommission(
                chargingOperationIndex: 0,
                estimatedAmount: 8_504_214_179
            )
        )

        XCTAssertEqual(flow.netFinalAmountOut, 999_995_785_821)
    }

    func testSwapAfterChargingScalesTheDeduction() {
        let flow = AssetExchangeCommissionNetFlow(
            operations: [
                CommissionTestFixtures.metaOperation(amountIn: 1_000, amountOut: 2_000, label: .swap),
                CommissionTestFixtures.metaOperation(amountIn: 2_000, amountOut: 1_000, label: .swap)
            ],
            commission: CommissionTestFixtures.makeCommission(chargingOperationIndex: 0, estimatedAmount: 100)
        )

        XCTAssertEqual(flow.netFinalAmountOut, 950)
    }
}

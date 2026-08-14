import XCTest
@testable import novawallet
import BigInt

final class AssetExchangeCommissionNetFlowTests: XCTestCase {
    func testNoCommissionLeavesAmountsUntouched() {
        let flow = AssetExchangeCommissionNetFlow(
            operations: [CommissionTestFixtures.metaOperation(amountIn: 100, amountOut: 200)],
            commission: nil,
            chargingOperationIndex: nil
        )

        XCTAssertEqual(flow.netAmountOut(at: 0), 200)
        XCTAssertEqual(flow.netFinalAmountOut, 200)
    }

    func testDeductionAppliesAtChargingOperation() {
        let flow = AssetExchangeCommissionNetFlow(
            operations: [CommissionTestFixtures.metaOperation(amountIn: 1000, amountOut: 2000)],
            commission: CommissionTestFixtures.makeCommission(chargingEdgeIndex: 0, amount: 17),
            chargingOperationIndex: 0
        )

        XCTAssertEqual(flow.netAmountIn(at: 0), 1000)
        XCTAssertEqual(flow.netAmountOut(at: 0), 1983)
        XCTAssertEqual(flow.netFinalAmountOut, 1983)
    }

    func testDeductionPropagatesThroughLaterOperations() {
        let flow = AssetExchangeCommissionNetFlow(
            operations: [
                CommissionTestFixtures.metaOperation(amountIn: 1000, amountOut: 2000),
                CommissionTestFixtures.metaOperation(amountIn: 2000, amountOut: 1000)
            ],
            commission: CommissionTestFixtures.makeCommission(chargingEdgeIndex: 0, amount: 100),
            chargingOperationIndex: 0
        )

        XCTAssertEqual(flow.netAmountOut(at: 0), 1900)
        XCTAssertEqual(flow.netAmountIn(at: 1), 1900)
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
                chargingEdgeIndex: 0,
                amount: 8_504_214_179
            ),
            chargingOperationIndex: 0
        )

        XCTAssertEqual(flow.netFinalAmountOut, 999_995_785_821)
    }

    func testSwapAfterChargingScalesTheDeduction() {
        let flow = AssetExchangeCommissionNetFlow(
            operations: [
                CommissionTestFixtures.metaOperation(amountIn: 1000, amountOut: 2000, label: .swap),
                CommissionTestFixtures.metaOperation(amountIn: 2000, amountOut: 1000, label: .swap)
            ],
            commission: CommissionTestFixtures.makeCommission(chargingEdgeIndex: 0, amount: 100),
            chargingOperationIndex: 0
        )

        XCTAssertEqual(flow.netFinalAmountOut, 950)
    }
}

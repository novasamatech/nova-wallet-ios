import XCTest
@testable import novawallet
import BigInt

final class AssetExchangeFeeTests: XCTestCase {
    func testInitialAmountInUnchangedByCommission() throws {
        let feeWithCommission = makeFee(commission: CommissionTestFixtures.makeCommission())
        let feeWithoutCommission = makeFee(commission: nil)

        let amountWithCommission = try feeWithCommission.getInitialAmountIn()
        let amountWithoutCommission = try feeWithoutCommission.getInitialAmountIn()

        XCTAssertEqual(amountWithCommission, 1_000_300)
        XCTAssertEqual(amountWithoutCommission, 1_000_300)
        XCTAssertEqual(amountWithCommission, amountWithoutCommission)
    }
}

private extension AssetExchangeFeeTests {
    func makeFee(commission: AssetExchangeCommission?) -> AssetExchangeFee {
        let operationFee = AssetExchangeOperationFee(
            submissionFee: .init(
                amountWithAsset: .init(amount: 700, asset: CommissionTestFixtures.asset(0)),
                payer: nil,
                weight: .zero
            ),
            postSubmissionFee: .init(
                paidByAccount: [],
                paidFromAmount: [.init(amount: 50, asset: CommissionTestFixtures.asset(0))]
            )
        )

        return AssetExchangeFee(
            route: CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000),
            operationFees: [operationFee],
            intermediateFeesInAssetIn: 250,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: commission
        )
    }
}

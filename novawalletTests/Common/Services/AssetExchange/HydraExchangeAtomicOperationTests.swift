import XCTest
@testable import novawallet
import BigInt

final class HydraExchangeAtomicOperationTests: XCTestCase {
    func testExecuteReturnsNetAmount() {
        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 5_829_600,
            amountOut: 5_829_600,
            slippage: BigRational(numerator: 1, denominator: 100)
        )
        let commission = CommissionTestFixtures.makeCommission(amount: 49133)
        let storageInfo = CommissionTestFixtures.ormlInfo(existentialDeposit: 1)

        let chargingParams = CommissionTestFixtures.makeSwapParams(
            commission: commission,
            storageInfo: storageInfo,
            callArgs: callArgs
        )

        XCTAssertEqual(
            HydraExchangeAtomicOperation.netAmountOut(from: 5_829_600, params: chargingParams),
            5_780_467
        )

        let noCommissionParams = CommissionTestFixtures.makeSwapParams(
            commission: nil,
            storageInfo: storageInfo,
            callArgs: callArgs
        )

        XCTAssertEqual(
            HydraExchangeAtomicOperation.netAmountOut(from: 5_829_600, params: noCommissionParams),
            5_829_600
        )

        XCTAssertEqual(
            HydraExchangeAtomicOperation.netAmountOut(from: 1, params: chargingParams),
            0
        )
    }
}

import XCTest
@testable import novawallet
import BigInt

final class HydraExchangeExtrinsicParamsFactoryTests: XCTestCase {
    func testTransferAmountIsRateOfCallAmountOut() {
        let slippages = [
            BigRational(numerator: 0, denominator: 1000),
            BigRational(numerator: 5, denominator: 1000),
            BigRational(numerator: 5, denominator: 100)
        ]

        for direction in [AssetConversion.Direction.sell, .buy] {
            for slippage in slippages {
                assertCommissionAmount(
                    direction: direction,
                    amountOut: 1_000_000,
                    slippage: slippage,
                    expected: 8500
                )
            }
        }

        assertCommissionAmount(
            direction: .buy,
            amountOut: 1_008_572_870,
            slippage: BigRational(numerator: 5, denominator: 100),
            expected: 8_572_869
        )
    }

    func testTransferAmountTracksCorrectedSwapLimit() {
        let commission = CommissionTestFixtures.makeCommission()

        let originalLimit = AssetExchangeSwapLimit(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 1, denominator: 100)
        )
        let originalCallArgs = callArgs(from: originalLimit)
        let originalAmount = HydraExchangeExtrinsicParamsFactory.commissionAmount(
            for: commission,
            callArgs: originalCallArgs
        )

        XCTAssertEqual(originalAmount, 8500)
        assertMatchesBoundFormula(amount: originalAmount, callArgs: originalCallArgs, commission: commission)

        let correctedLimit = originalLimit.replacingAmountIn(500_000, shouldReplaceBuyWithSell: false)
        let correctedCallArgs = callArgs(from: correctedLimit)
        let correctedAmount = HydraExchangeExtrinsicParamsFactory.commissionAmount(
            for: commission,
            callArgs: correctedCallArgs
        )

        XCTAssertEqual(correctedAmount, 4250)
        assertMatchesBoundFormula(amount: correctedAmount, callArgs: correctedCallArgs, commission: commission)
    }

    func testZeroDerivedAmountOmitsTransfer() throws {
        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 117,
            amountOut: 117,
            slippage: BigRational(numerator: 0, denominator: 100)
        )
        let commission = CommissionTestFixtures.makeCommission()
        let storageInfo = CommissionTestFixtures.ormlInfo(module: "Tokens")

        XCTAssertNil(
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: storageInfo,
                callArgs: callArgs
            )
        )

        let params = CommissionTestFixtures.makeSwapParams(
            commission: commission,
            storageInfo: storageInfo,
            callArgs: callArgs
        )
        let calls = try CommissionTestFixtures.makeRecordedCalls(params)

        XCTAssertEqual(calls, [CallCodingPath(moduleName: "Omnipool", callName: "sell")])
    }

    func testNoCommissionMeansNoTransferCall() throws {
        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )
        let commission = CommissionTestFixtures.makeCommission()
        let storageInfo = CommissionTestFixtures.ormlInfo(module: "Tokens")

        XCTAssertNil(
            HydraExchangeExtrinsicParamsFactory.commissionParams(for: nil, storageInfo: storageInfo, callArgs: callArgs)
        )
        XCTAssertNil(
            HydraExchangeExtrinsicParamsFactory.commissionParams(for: commission, storageInfo: nil, callArgs: callArgs)
        )

        let paramsNoCommission = CommissionTestFixtures.makeSwapParams(
            commission: nil,
            storageInfo: storageInfo,
            callArgs: callArgs
        )
        let callsNoCommission = try CommissionTestFixtures.makeRecordedCalls(paramsNoCommission)
        XCTAssertEqual(callsNoCommission, [CallCodingPath(moduleName: "Omnipool", callName: "sell")])

        let paramsNoStorageInfo = CommissionTestFixtures.makeSwapParams(
            commission: commission,
            storageInfo: nil,
            callArgs: callArgs
        )
        let callsNoStorageInfo = try CommissionTestFixtures.makeRecordedCalls(paramsNoStorageInfo)
        XCTAssertEqual(callsNoStorageInfo, [CallCodingPath(moduleName: "Omnipool", callName: "sell")])
    }

    func testBatchContainsSwapAndTransfer() throws {
        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )
        let commission = CommissionTestFixtures.makeCommission()

        let ormlParams = CommissionTestFixtures.makeSwapParams(
            commission: commission,
            storageInfo: CommissionTestFixtures.ormlInfo(module: "Tokens"),
            callArgs: callArgs
        )
        let ormlCalls = try CommissionTestFixtures.makeRecordedCalls(ormlParams)

        XCTAssertEqual(
            ormlCalls,
            [
                CallCodingPath(moduleName: "Omnipool", callName: "sell"),
                CallCodingPath(moduleName: "Tokens", callName: "transfer")
            ]
        )

        let nativeParams = CommissionTestFixtures.makeSwapParams(
            commission: commission,
            storageInfo: CommissionTestFixtures.nativeInfo(),
            callArgs: callArgs
        )
        let nativeCalls = try CommissionTestFixtures.makeRecordedCalls(nativeParams)

        XCTAssertEqual(nativeCalls.last, .transferKeepAlive)
    }

    func testTransferGoesToConfiguredBeneficiary() throws {
        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )
        let commission = CommissionTestFixtures.makeCommission()

        let commissionParams = try XCTUnwrap(
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: CommissionTestFixtures.ormlInfo(module: "Tokens"),
                callArgs: callArgs
            )
        )

        XCTAssertEqual(commissionParams.beneficiary, commission.beneficiary)
    }

    func testFeeAndSubmissionClosuresMatch() throws {
        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )
        let commission = CommissionTestFixtures.makeCommission()
        let params = CommissionTestFixtures.makeSwapParams(
            commission: commission,
            storageInfo: CommissionTestFixtures.ormlInfo(module: "Tokens"),
            callArgs: callArgs
        )

        let feeBuilder = RecordingExtrinsicBuilder()
        let submissionBuilder = RecordingExtrinsicBuilder()

        _ = try HydraExchangeExtrinsicConverter.addingOperation(from: params, builder: feeBuilder)
        _ = try HydraExchangeExtrinsicConverter.addingOperation(from: params, builder: submissionBuilder)

        XCTAssertEqual(feeBuilder.addedCalls, submissionBuilder.addedCalls)
    }
}

private extension HydraExchangeExtrinsicParamsFactoryTests {
    func callArgs(from limit: AssetExchangeSwapLimit) -> AssetConversion.CallArgs {
        CommissionTestFixtures.makeCallArgs(
            direction: limit.direction,
            amountIn: limit.amountIn,
            amountOut: limit.amountOut,
            slippage: limit.slippage
        )
    }

    func assertCommissionAmount(
        direction: AssetConversion.Direction,
        amountOut: Balance,
        slippage: BigRational,
        expected: Balance
    ) {
        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: direction,
            amountIn: amountOut,
            amountOut: amountOut,
            slippage: slippage
        )
        let commission = CommissionTestFixtures.makeCommission()

        let amount = HydraExchangeExtrinsicParamsFactory.commissionAmount(for: commission, callArgs: callArgs)

        XCTAssertEqual(amount, expected)
        XCTAssertNotEqual(amount, commission.estimatedAmount)
    }

    func assertMatchesBoundFormula(
        amount: Balance,
        callArgs: AssetConversion.CallArgs,
        commission: AssetExchangeCommission
    ) {
        XCTAssertEqual(amount, commission.rate.mul(value: callArgs.amountOut))
    }
}

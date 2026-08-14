import XCTest
@testable import novawallet
import BigInt

final class HydraExchangeExtrinsicParamsFactoryTests: XCTestCase {
    func testTransferAmountIsTheResolvedCommissionAmount() {
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
                    expected: 8428
                )
            }
        }

        assertCommissionAmount(
            direction: .buy,
            amountOut: 1_008_500_000,
            slippage: BigRational(numerator: 5, denominator: 100),
            expected: 8428
        )
    }

    func testTransferAmountIgnoresCorrectedSwapLimit() throws {
        let commission = CommissionTestFixtures.makeCommission()
        let storageInfo = CommissionTestFixtures.ormlInfo(module: "Tokens")

        let originalLimit = AssetExchangeSwapLimit(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 1, denominator: 100)
        )
        let correctedLimit = originalLimit.replacingAmountIn(500_000, shouldReplaceBuyWithSell: false)

        XCTAssertEqual(correctedLimit.amountOut, 500_000)

        for limit in [originalLimit, correctedLimit] {
            let params = CommissionTestFixtures.makeSwapParams(
                commission: commission,
                storageInfo: storageInfo,
                callArgs: callArgs(from: limit)
            )

            XCTAssertEqual(params.commission?.amount, 8428)
        }
    }

    func testZeroCommissionAmountOmitsTransfer() throws {
        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 117,
            amountOut: 117,
            slippage: BigRational(numerator: 0, denominator: 100)
        )
        let commission = CommissionTestFixtures.makeCommission(amount: 0)
        let storageInfo = CommissionTestFixtures.ormlInfo(module: "Tokens")

        XCTAssertNil(
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: storageInfo
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
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: nil,
                storageInfo: storageInfo
            )
        )
        XCTAssertNil(
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: nil
            )
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
                .tokensTransfer
            ]
        )

        let nativeParams = CommissionTestFixtures.makeSwapParams(
            commission: commission,
            storageInfo: CommissionTestFixtures.nativeInfo(),
            callArgs: callArgs
        )
        let nativeCalls = try CommissionTestFixtures.makeRecordedCalls(nativeParams)

        XCTAssertEqual(nativeCalls.last, .transferAllowDeath)
    }

    func testBuyCommissionIgnoresDownstreamFeeTopUp() throws {
        let grossedTarget: Balance = 10_085_000_000
        let resolvedAmount = AssetExchangeCommissionConstants.rate.asShareOfGross.mul(value: grossedTarget)

        XCTAssertEqual(resolvedAmount, 85_000_000)

        let commission = AssetExchangeCommission(
            chargingOperationIndex: 0,
            asset: CommissionTestFixtures.asset(1),
            amount: resolvedAmount,
            beneficiary: CommissionTestFixtures.beneficiary
        )

        let inflatedCallArgs = CommissionTestFixtures.makeCallArgs(
            direction: .buy,
            amountIn: 1_001_982_999_999,
            amountOut: 10_125_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )

        let params = CommissionTestFixtures.makeSwapParams(
            commission: commission,
            storageInfo: CommissionTestFixtures.ormlInfo(module: "Tokens"),
            callArgs: inflatedCallArgs
        )

        XCTAssertEqual(params.commission?.amount, resolvedAmount)
    }

    func testSellCommissionIgnoresRealizedAmountOut() throws {
        let commission = CommissionTestFixtures.makeCommission()

        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 700_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )

        let params = CommissionTestFixtures.makeSwapParams(
            commission: commission,
            storageInfo: CommissionTestFixtures.ormlInfo(module: "Tokens"),
            callArgs: callArgs
        )

        XCTAssertEqual(params.commission?.amount, 8428)
    }

    func testTransferGoesToConfiguredBeneficiary() throws {
        let commission = CommissionTestFixtures.makeCommission()

        let commissionParams = try XCTUnwrap(
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: CommissionTestFixtures.ormlInfo(module: "Tokens")
            )
        )

        XCTAssertEqual(commissionParams.beneficiary, commission.beneficiary)
    }

    func testCommissionTransferIsNotKeepAliveAndBatchIsAtomic() throws {
        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )
        let commission = CommissionTestFixtures.makeCommission()

        for storageInfo in [
            CommissionTestFixtures.ormlInfo(module: "Tokens"),
            CommissionTestFixtures.ormlHydrationEvmInfo(module: "Currencies")
        ] {
            let params = CommissionTestFixtures.makeSwapParams(
                commission: commission,
                storageInfo: storageInfo,
                callArgs: callArgs
            )

            let builder = try CommissionTestFixtures.record(params)
            let transferCall = try XCTUnwrap(builder.addedCalls.last)

            XCTAssertEqual(transferCall.callName, "transfer")
            XCTAssertEqual(builder.batchType, .atomic)

            let args = try XCTUnwrap(
                builder.addedCallArgs.compactMap { $0 as? OrmlTokensPallet.TransferCall }.last
            )

            XCTAssertEqual(args.amount, 8428)
            XCTAssertEqual(args.dest.accountId, commission.beneficiary)
        }
    }

    func testCommissionAmountIsIndependentOfCallAmountOut() throws {
        let commission = CommissionTestFixtures.makeCommission(amount: 1000)
        let storageInfo = CommissionTestFixtures.ormlInfo(module: "Tokens")

        for amountOut: Balance in [1000, 1_000_000, 1_000_000_000] {
            let params = CommissionTestFixtures.makeSwapParams(
                commission: commission,
                storageInfo: storageInfo,
                callArgs: CommissionTestFixtures.makeCallArgs(
                    direction: .sell,
                    amountIn: amountOut,
                    amountOut: amountOut,
                    slippage: BigRational(numerator: 0, denominator: 100)
                )
            )

            XCTAssertEqual(params.commission?.amount, 1000)
        }
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

        let params = CommissionTestFixtures.makeSwapParams(
            commission: commission,
            storageInfo: CommissionTestFixtures.ormlInfo(module: "Tokens"),
            callArgs: callArgs
        )

        XCTAssertEqual(params.commission?.amount, expected)
    }
}

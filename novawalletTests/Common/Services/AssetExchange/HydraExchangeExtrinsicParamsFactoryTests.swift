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
                    expected: 8428
                )
            }
        }

        assertCommissionAmount(
            direction: .buy,
            amountOut: 1_008_500_000,
            slippage: BigRational(numerator: 5, denominator: 100),
            expected: 8_500_000
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

        XCTAssertEqual(originalAmount, 8428)

        let correctedLimit = originalLimit.replacingAmountIn(500_000, shouldReplaceBuyWithSell: false)
        let correctedCallArgs = callArgs(from: correctedLimit)
        let correctedAmount = HydraExchangeExtrinsicParamsFactory.commissionAmount(
            for: commission,
            callArgs: correctedCallArgs
        )

        XCTAssertEqual(correctedAmount, 4214)
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

    func testCommissionIsDroppedBelowChargedAssetExistentialDeposit() {
        let commission = CommissionTestFixtures.makeCommission()

        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )

        XCTAssertEqual(
            HydraExchangeExtrinsicParamsFactory.commissionAmount(for: commission, callArgs: callArgs),
            8428
        )

        XCTAssertNil(
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: CommissionTestFixtures.ormlInfo(existentialDeposit: 8429),
                callArgs: callArgs
            )
        )

        XCTAssertNotNil(
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: CommissionTestFixtures.ormlInfo(existentialDeposit: 8428),
                callArgs: callArgs
            )
        )
    }

    func testNativeCommissionHasNoExistentialDepositFloor() {
        let commission = CommissionTestFixtures.makeCommission()

        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 1_000,
            amountOut: 1_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )

        XCTAssertEqual(
            HydraExchangeExtrinsicParamsFactory.commissionAmount(for: commission, callArgs: callArgs),
            8
        )

        XCTAssertNotNil(
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: CommissionTestFixtures.nativeInfo(),
                callArgs: callArgs
            )
        )
    }

    func testCommissionIsDroppedWhenExistentialDepositIsUnknown() {
        let commission = CommissionTestFixtures.makeCommission()

        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )

        XCTAssertNil(
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: CommissionTestFixtures.statemineInfo(),
                callArgs: callArgs
            )
        )

        XCTAssertNotNil(
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: CommissionTestFixtures.ormlHydrationEvmInfo(),
                callArgs: callArgs
            )
        )
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
                storageInfo: storageInfo,
                callArgs: callArgs
            )
        )
        XCTAssertNil(
            HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: nil,
                callArgs: callArgs
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
        let estimatedAmount = AssetExchangeCommissionConstants.rate.asShareOfGross.mul(value: grossedTarget)

        XCTAssertEqual(estimatedAmount, 85_000_000)

        let commission = AssetExchangeCommission(
            chargingOperationIndex: 0,
            asset: CommissionTestFixtures.asset(1),
            estimatedAmount: estimatedAmount,
            beneficiary: CommissionTestFixtures.beneficiary,
            rateOfGross: AssetExchangeCommissionConstants.rate.asShareOfGross
        )

        let inflatedCallArgs = CommissionTestFixtures.makeCallArgs(
            direction: .buy,
            amountIn: 1_001_982_999_999,
            amountOut: 10_125_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )

        XCTAssertEqual(
            HydraExchangeExtrinsicParamsFactory.commissionAmount(
                for: commission,
                callArgs: inflatedCallArgs
            ),
            estimatedAmount
        )
    }

    func testSellCommissionTracksRealizedAmountOut() throws {
        let commission = CommissionTestFixtures.makeCommission()

        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 700_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )

        XCTAssertEqual(
            HydraExchangeExtrinsicParamsFactory.commissionAmount(for: commission, callArgs: callArgs),
            5_899_851
        )
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

    func testSellCommissionIsCappedByTheEstimate() {
        let commission = CommissionTestFixtures.makeCommission()
        let cappedCommission = AssetExchangeCommission(
            chargingOperationIndex: commission.chargingOperationIndex,
            asset: commission.asset,
            estimatedAmount: 1000,
            beneficiary: commission.beneficiary,
            rateOfGross: commission.rateOfGross
        )

        let inflatedCallArgs = CommissionTestFixtures.makeCallArgs(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        )

        XCTAssertEqual(
            HydraExchangeExtrinsicParamsFactory.commissionAmount(
                for: cappedCommission,
                callArgs: inflatedCallArgs
            ),
            1000
        )
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
}

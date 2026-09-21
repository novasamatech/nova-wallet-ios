import XCTest
@testable import novawallet
import BigInt

final class AssetHubExchangeAtomicOperationTests: XCTestCase {
    func testSellFallsBackToPalletMinimumLessCommission() throws {
        let params = try createParams(swap: .exactIn(createSellCall(amountOutMin: 990_085)), commission: 8428)

        XCTAssertEqual(AssetHubExchangeAtomicOperation.guaranteedNetAmountOut(for: params), 981_657)
    }

    func testBuyFallsBackToExactTargetLessCommission() throws {
        let params = try createParams(swap: .exactOut(createBuyCall(amountOut: 1_008_500)), commission: 8500)

        XCTAssertEqual(AssetHubExchangeAtomicOperation.guaranteedNetAmountOut(for: params), 1_000_000)
    }

    func testUnchargedSwapFallsBackToPalletMinimum() throws {
        let params = try createParams(swap: .exactIn(createSellCall(amountOutMin: 990_085)), commission: nil)

        XCTAssertEqual(AssetHubExchangeAtomicOperation.guaranteedNetAmountOut(for: params), 990_085)
    }

    func testCommissionAbovePalletBoundFallsBackToZero() throws {
        let params = try createParams(swap: .exactIn(createSellCall(amountOutMin: 1000)), commission: 5000)

        XCTAssertEqual(AssetHubExchangeAtomicOperation.guaranteedNetAmountOut(for: params), 0)
    }

    func testCommissionIsWaivedWhenItNoLongerFitsTheRescaledSwap() {
        XCTAssertTrue(AssetHubExchangeAtomicOperation.shouldWaiveCommission(
            on: AssetHubExchangePreparationError.invalidCommission
        ))
        XCTAssertTrue(AssetHubExchangeAtomicOperation.shouldWaiveCommission(
            on: AssetHubExchangePreparationError.netOutputBelowMinimum
        ))
    }

    func testUnreadyRecipientDoesNotWaiveCommission() {
        XCTAssertFalse(AssetHubExchangeAtomicOperation.shouldWaiveCommission(
            on: AssetHubExchangePreparationError.recipientUnavailable
        ))
    }

    func testUnrelatedPreparationFailuresDoNotWaiveCommission() {
        let errors: [Error] = [
            AssetHubExchangePreparationError.invalidSlippage,
            AssetHubExchangePreparationError.unsupportedStorage,
            AssetHubExchangePreparationError.runtimeCallUnavailable(.transferKeepAlive),
            CommonError.dataCorruption
        ]

        errors.forEach {
            XCTAssertFalse(AssetHubExchangeAtomicOperation.shouldWaiveCommission(on: $0))
        }
    }
}

private extension AssetHubExchangeAtomicOperationTests {
    static let receiver = AccountId(repeating: 1, count: 32)
    static let beneficiary = AccountId(repeating: 9, count: 32)

    func createSellCall(amountOutMin: Balance) -> AssetConversionPallet.SwapExactTokensForTokensCall {
        .init(
            path: [],
            amountIn: 1_000_000,
            amountOutMin: amountOutMin,
            sendTo: Self.receiver,
            keepAlive: false
        )
    }

    func createBuyCall(amountOut: Balance) -> AssetConversionPallet.SwapTokensForExactTokensCall {
        .init(
            path: [],
            amountOut: amountOut,
            amountInMax: 2_000_000,
            sendTo: Self.receiver,
            keepAlive: false
        )
    }

    func createParams(
        swap: AssetHubExchangeSwapParams.Swap,
        commission: Balance?
    ) throws -> AssetHubExchangeSwapParams {
        let codingOperation = try RuntimeCodingServiceStub.createWestendService().fetchCoderFactoryOperation()
        OperationQueue().addOperations([codingOperation], waitUntilFinished: true)

        return AssetHubExchangeSwapParams(
            callArgs: .init(
                assetIn: ChainAssetId(chainId: "0", assetId: 0),
                amountIn: 1_000_000,
                assetOut: ChainAssetId(chainId: "0", assetId: 1),
                amountOut: 1_000_000,
                receiver: Self.receiver,
                direction: .sell,
                slippage: BigRational(numerator: 1, denominator: 100)
            ),
            path: [],
            swap: swap,
            commission: commission.map {
                .init(
                    amount: $0,
                    beneficiary: Self.beneficiary,
                    assetStorageInfo: CommissionTestFixtures.nativeInfo()
                )
            },
            codingFactory: try codingOperation.extractNoCancellableResultData()
        )
    }
}

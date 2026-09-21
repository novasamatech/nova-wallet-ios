import XCTest
@testable import novawallet
import BigInt

final class AssetHubExchangeAtomicOperationTests: XCTestCase {
    func testSellFallsBackToPalletMinimumLessCommission() throws {
        let params = try createParams(swap: .exactIn(createSellCall(amountOutMin: 990_085)), commission: 8428)

        XCTAssertEqual(AssetHubExchangeAtomicOperation.guaranteedNetAmountOut(for: params), 981_657)
    }

    func testSwapWithoutExecutionEventIsReportedAsNotDispatched() throws {
        let codingFactory = try createCodingFactory()
        let verification = AssetConversionSwapVerification(
            receiver: Self.receiver,
            path: [],
            bounds: .exactIn(amountIn: 1_000_000, amountOutMin: 990_085),
            commission: nil
        )

        XCTAssertThrowsError(try AssetConversionEventParser(logger: Logger.shared).measure(
            from: [],
            verification: verification,
            origin: Self.receiver,
            using: codingFactory
        )) {
            XCTAssertEqual($0 as? AssetHubExchangeEventError, .swapNotDispatched)
        }
    }

    func testUndispatchedSwapDoesNotFallBackToGuaranteedBound() {
        XCTAssertFalse(AssetHubExchangeAtomicOperation.shouldUseGuaranteedBound(
            on: AssetHubExchangeEventError.swapNotDispatched
        ))
        XCTAssertTrue(AssetHubExchangeAtomicOperation.shouldUseGuaranteedBound(
            on: AssetHubExchangeEventError.missingOrAmbiguousCommission
        ))
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

    func createCodingFactory() throws -> RuntimeCoderFactoryProtocol {
        let codingOperation = try RuntimeCodingServiceStub.createWestendService().fetchCoderFactoryOperation()
        OperationQueue().addOperations([codingOperation], waitUntilFinished: true)

        return try codingOperation.extractNoCancellableResultData()
    }

    func createParams(
        swap: AssetHubExchangeSwapParams.Swap,
        commission: Balance?
    ) throws -> AssetHubExchangeSwapParams {
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
            codingFactory: try createCodingFactory()
        )
    }
}

import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo
import BigInt

final class HydraFeeQuoteFactoryTests: XCTestCase {
    private let feeAsset = ChainAssetId(chainId: KnowChainId.hydra, assetId: 1)
    private let nativeAsset = ChainAssetId(chainId: KnowChainId.hydra, assetId: 0)

    func testConvertsTheNativeFeeAtTheOraclePriceOfTheFeeAsset() throws {
        // given
        var requestedAssetId: ChainAssetId?

        let priceFactory = makePriceFactory(
            returning: .init(inner: BigUInt("1200000000000000000"))
        ) { requestedAssetId = $0 }

        // when
        let quote = try quote(with: priceFactory, direction: .buy)

        // then
        XCTAssertEqual(requestedAssetId, feeAsset)
        XCTAssertEqual(quote.amountIn, BigUInt("1200000000000"))
        XCTAssertEqual(quote.amountOut, BigUInt("1000000000000"))
        XCTAssertEqual(quote.assetIn, feeAsset)
        XCTAssertEqual(quote.assetOut, nativeAsset)
    }

    func testRejectsSellDirectionRatherThanQuotingTheInverse() throws {
        let priceFactory = makePriceFactory(returning: .one)

        XCTAssertThrowsError(try quote(with: priceFactory, direction: .sell)) { error in
            guard case HydraFeeOraclePriceError.unsupportedQuoteDirection(.sell) = error else {
                return XCTFail("unexpected error \(error)")
            }
        }

        verify(priceFactory, never()).createPriceWrapper(for: any())
    }

    func testPropagatesPriceFactoryFailure() throws {
        let priceFactory = MockHydraFeeOraclePriceFactoryProtocol()

        stub(priceFactory) { stub in
            when(stub.createPriceWrapper(for: any())).then { chainAssetId in
                .createWithError(HydraFeeOraclePriceError.assetNotAcceptedAsFee(chainAssetId))
            }
        }

        XCTAssertThrowsError(try quote(with: priceFactory, direction: .buy)) { error in
            guard case HydraFeeOraclePriceError.assetNotAcceptedAsFee = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }
}

private extension HydraFeeQuoteFactoryTests {
    func makePriceFactory(
        returning price: HydraFeeConversion.Price,
        onRequest: @escaping (ChainAssetId) -> Void = { _ in }
    ) -> MockHydraFeeOraclePriceFactoryProtocol {
        let priceFactory = MockHydraFeeOraclePriceFactoryProtocol()

        stub(priceFactory) { stub in
            when(stub.createPriceWrapper(for: any())).then { chainAssetId in
                onRequest(chainAssetId)

                return .createWithResult(price)
            }
        }

        return priceFactory
    }

    func quote(
        with priceFactory: HydraFeeOraclePriceFactoryProtocol,
        direction: AssetConversion.Direction
    ) throws -> AssetConversion.Quote {
        let wrapper = HydraFeeQuoteFactory(priceFactory: priceFactory).quote(
            for: AssetConversion.QuoteArgs(
                assetIn: feeAsset,
                assetOut: nativeAsset,
                amount: BigUInt("1000000000000"),
                direction: direction
            )
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

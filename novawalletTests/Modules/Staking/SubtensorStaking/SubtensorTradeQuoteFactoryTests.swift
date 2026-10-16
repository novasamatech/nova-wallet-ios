import BigInt
import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorTradeQuoteFactoryTests: XCTestCase {
    private let bestBlockHash = "0x1a7d81b7dbe1505dbe063cbecebfc64d0b5a0c39e9bb7a755be17dd9c8fbcd62"
    private let beneficiary = Data(repeating: 0xBB, count: 32)
    private let netuid: UInt16 = 64
    private let tolerance = BigRational(numerator: 5, denominator: 1000)

    func testBuyQuoteSimulatesTheStakeNetOfNovaFeeAtOneBlock() throws {
        let sim = generateBuySim(alphaOut: 67_054_958_000)
        let apiFactory = createApiFactory(sim: sim)

        let factory = createFactory(apiFactory: apiFactory)

        let tradeQuote = try run(
            factory.createTradeQuoteWrapper(for: .buy(
                netuid: netuid,
                grossTao: 5_000_000_000,
                tolerance: tolerance
            ))
        )

        let expected = SubtensorTradeQuote(
            quote: generateQuote(
                direction: .stake(taoIn: 4_985_044_866),
                sim: sim,
                capturedAt: tradeQuote.quote.capturedAt
            ),
            amountIn: 5_000_000_000,
            novaFee: SubtensorNovaFee(amount: 14_955_134, beneficiary: beneficiary),
            expectedOut: 67_054_958_000,
            swapMinimumOut: 67_178_129_124,
            minimumOut: 67_178_129_124,
            limitPrice: 74_169_000
        )
        XCTAssertEqual(tradeQuote, expected)

        let simHashCaptor = ArgumentCaptor<BlockHash?>()
        let priceHashCaptor = ArgumentCaptor<BlockHash?>()
        let feeRateHashCaptor = ArgumentCaptor<BlockHash?>()
        verify(apiFactory, times(1)).createSimSwapTaoForAlphaWrapper(
            netuid: equal(to: netuid),
            taoAmount: equal(to: BigUInt(4_985_044_866)),
            blockHash: simHashCaptor.capture()
        )
        verify(apiFactory, times(1)).createAlphaPriceWrapper(
            for: equal(to: netuid),
            blockHash: priceHashCaptor.capture()
        )
        verify(apiFactory, times(1)).createFeeRateWrapper(
            for: equal(to: netuid),
            blockHash: feeRateHashCaptor.capture()
        )
        XCTAssertEqual(simHashCaptor.value, bestBlockHash)
        XCTAssertEqual(priceHashCaptor.value, bestBlockHash)
        XCTAssertEqual(feeRateHashCaptor.value, bestBlockHash)
    }

    func testSellQuoteChargesNovaFeeOnTheQuotedTaoOut() throws {
        let sim = generateSellSim(taoOut: 4_145_000_000)
        let apiFactory = createApiFactory(sim: sim)

        let factory = createFactory(apiFactory: apiFactory)

        let tradeQuote = try run(
            factory.createTradeQuoteWrapper(for: .sell(
                netuid: netuid,
                alpha: 56_200_000_000,
                tolerance: tolerance
            ))
        )

        let expected = SubtensorTradeQuote(
            quote: generateQuote(
                direction: .unstake(alphaIn: 56_200_000_000),
                sim: sim,
                capturedAt: tradeQuote.quote.capturedAt
            ),
            amountIn: 56_200_000_000,
            novaFee: SubtensorNovaFee(amount: 12_397_806, beneficiary: beneficiary),
            expectedOut: 4_132_602_194,
            swapMinimumOut: 4_124_744_148,
            minimumOut: 4_112_346_342,
            limitPrice: 73_431_000
        )
        XCTAssertEqual(tradeQuote, expected)
        verify(apiFactory, times(1)).createSimSwapAlphaForTaoWrapper(
            netuid: equal(to: netuid),
            alphaAmount: equal(to: BigUInt(56_200_000_000)),
            blockHash: any()
        )
    }

    func testStakeQuoteTakesTheFeeFromTheTaoSide() throws {
        let sim = SubtensorStakingPallet.SimSwapResult(
            taoAmount: 999_496_453,
            alphaAmount: 130_082_405_209,
            taoFee: 503_547,
            alphaFee: 0
        )

        let factory = createFactory(apiFactory: createApiFactory(sim: sim, spot: 7_683_255))

        let quote = try run(
            factory.createTradeQuoteWrapper(for: .buy(
                netuid: netuid,
                grossTao: 1_000_000_000,
                tolerance: tolerance
            ))
        ).quote

        XCTAssertEqual(quote.expectedOut, BigUInt(130_082_405_209))
        XCTAssertEqual(quote.poolFee, BigUInt(503_547))
        XCTAssertEqual(quote.priceImpact?.mul(value: 1_000_000), 80)
    }

    func testUnstakeQuoteTakesTheFeeFromTheAlphaSide() throws {
        let sim = SubtensorStakingPallet.SimSwapResult(
            taoAmount: 998_912_946,
            alphaAmount: 130_016_902_511,
            taoFee: 0,
            alphaFee: 65_502_698
        )

        let factory = createFactory(apiFactory: createApiFactory(sim: sim, spot: 7_683_255))

        let quote = try run(
            factory.createTradeQuoteWrapper(for: .sell(
                netuid: netuid,
                alpha: 130_082_405_209,
                tolerance: tolerance
            ))
        ).quote

        XCTAssertEqual(quote.expectedOut, BigUInt(998_912_946))
        XCTAssertEqual(quote.poolFee, BigUInt(65_502_698))
        XCTAssertEqual(quote.priceImpact?.mul(value: 1_000_000), 80)
    }

    func testLargeBuyPriceImpactIsThePoolPriceMove() throws {
        let sim = SubtensorStakingPallet.SimSwapResult(
            taoAmount: 1_199_395_742_733,
            alphaAmount: 16_156_594_429_601,
            taoFee: 604_257_267,
            alphaFee: 0
        )

        let factory = createFactory(apiFactory: createApiFactory(sim: sim))

        let tradeQuote = try run(
            factory.createTradeQuoteWrapper(for: .buy(
                netuid: netuid,
                grossTao: 1_200_000_000_000,
                tolerance: tolerance
            ))
        )

        XCTAssertEqual(tradeQuote.quote.priceImpact?.mul(value: 1_000_000), 11841)
    }

    func testBuyWhosePostTradePriceReachesTheLimitIsNotFillable() throws {
        let apiFactory = createApiFactory(sim: generateBuySim(alphaOut: 66_964_347_135))

        let factory = createFactory(apiFactory: apiFactory)

        let tradeQuote = try run(
            factory.createTradeQuoteWrapper(for: .buy(
                netuid: netuid,
                grossTao: 5_000_000_000,
                tolerance: tolerance
            ))
        )

        XCTAssertFalse(tradeQuote.isFillable(atLimit: tradeQuote.limitPrice))
    }

    func testZeroOutSimFailsAsQuoteUnavailable() {
        let sim = SubtensorStakingPallet.SimSwapResult(taoAmount: 0, alphaAmount: 0, taoFee: 0, alphaFee: 0)
        let factory = createFactory(apiFactory: createApiFactory(sim: sim))

        XCTAssertThrowsError(
            try run(factory.createTradeQuoteWrapper(for: .buy(netuid: netuid, grossTao: 1_000_000_000, tolerance: tolerance)))
        ) { error in
            XCTAssertEqual(error as? SubtensorQuoteError, .quoteUnavailable(netuid: netuid))
        }
    }

    func testBuyQuoteWithoutBeneficiaryFailsClosed() {
        let factory = SubtensorTradeQuoteFactory(
            operationFactory: MockSubtensorApiOperationFactoryProtocol(),
            operationQueue: OperationQueue(),
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: nil)
        )

        XCTAssertThrowsError(
            try run(factory.createTradeQuoteWrapper(for: .buy(netuid: netuid, grossTao: 5_000_000_000, tolerance: tolerance)))
        ) { error in
            XCTAssertEqual(error as? SubtensorStakingOperationError, .novaFeeUnavailable)
        }
    }

    private func createFactory(apiFactory: MockSubtensorApiOperationFactoryProtocol) -> SubtensorTradeQuoteFactory {
        SubtensorTradeQuoteFactory(
            operationFactory: apiFactory,
            operationQueue: OperationQueue(),
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: beneficiary)
        )
    }

    private func createApiFactory(
        sim: SubtensorStakingPallet.SimSwapResult,
        spot: Balance = 73_800_000
    ) -> MockSubtensorApiOperationFactoryProtocol {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createBestBlockHashWrapper()).thenReturn(CompoundOperationWrapper.createWithResult(bestBlockHash))
            when(stub.createSimSwapTaoForAlphaWrapper(netuid: any(), taoAmount: any(), blockHash: any()))
                .thenReturn(CompoundOperationWrapper.createWithResult(sim))
            when(stub.createSimSwapAlphaForTaoWrapper(netuid: any(), alphaAmount: any(), blockHash: any()))
                .thenReturn(CompoundOperationWrapper.createWithResult(sim))
            when(stub.createAlphaPriceWrapper(for: any(), blockHash: any()))
                .thenReturn(CompoundOperationWrapper.createWithResult(spot))
            when(stub.createFeeRateWrapper(for: any(), blockHash: any()))
                .thenReturn(CompoundOperationWrapper.createWithResult(33))
        }

        return apiFactory
    }

    private func generateBuySim(alphaOut: Balance) -> SubtensorStakingPallet.SimSwapResult {
        SubtensorStakingPallet.SimSwapResult(
            taoAmount: 4_955_361_688,
            alphaAmount: alphaOut,
            taoFee: 2_496_518,
            alphaFee: 0
        )
    }

    private func generateSellSim(taoOut: Balance) -> SubtensorStakingPallet.SimSwapResult {
        SubtensorStakingPallet.SimSwapResult(
            taoAmount: taoOut,
            alphaAmount: 56_171_700_618,
            taoFee: 0,
            alphaFee: 28_299_382
        )
    }

    private func generateQuote(
        direction: SubtensorQuoteArgs.Direction,
        sim: SubtensorStakingPallet.SimSwapResult,
        capturedAt: Date
    ) -> SubtensorQuote {
        SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: netuid, direction: direction),
            sim: sim,
            spotPrice: 73_800_000,
            feeRate: 33,
            capturedAt: capturedAt
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

import BigInt
import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorQuoteOperationFactoryTests: XCTestCase {
    let bestBlockHash = "0x1a7d81b7dbe1505dbe063cbecebfc64d0b5a0c39e9bb7a755be17dd9c8fbcd62"
    let netuid: UInt16 = 1
    let spotPrice = BigUInt(7_683_255)

    let buySim = SubtensorStakingPallet.SimSwapResult(
        taoAmount: 999_496_453,
        alphaAmount: 130_082_405_209,
        taoFee: 503_547,
        alphaFee: 0,
        taoSlippage: 0,
        alphaSlippage: 70_762_340
    )

    let sellSim = SubtensorStakingPallet.SimSwapResult(
        taoAmount: 998_912_946,
        alphaAmount: 130_016_902_511,
        taoFee: 0,
        alphaFee: 65_502_698,
        taoSlippage: 543_368,
        alphaSlippage: 0
    )

    var buyArgs: SubtensorQuoteArgs {
        SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: 1_000_000_000))
    }

    var sellArgs: SubtensorQuoteArgs {
        SubtensorQuoteArgs(netuid: netuid, direction: .unstake(alphaIn: 130_082_405_209))
    }

    func testStakeQuoteMergesSimSpotAndFeeRate() throws {
        let factory = makeFactory(sim: buySim)

        let quote = try fetchQuote(using: factory, args: buyArgs)

        XCTAssertEqual(quote.args, buyArgs)
        XCTAssertEqual(quote.sim, buySim)
        XCTAssertEqual(quote.spotPrice, spotPrice)
        XCTAssertEqual(quote.feeRate, 33)
        XCTAssertEqual(quote.expectedOut, BigUInt(130_082_405_209))
        XCTAssertEqual(quote.poolFee, BigUInt(503_547))
    }

    func testUnstakeQuoteTakesOutAndFeeFromTaoSide() throws {
        let factory = makeFactory(sim: sellSim)

        let quote = try fetchQuote(using: factory, args: sellArgs)

        XCTAssertEqual(quote.expectedOut, BigUInt(998_912_946))
        XCTAssertEqual(quote.poolFee, BigUInt(65_502_698))
    }

    func testStakeQuoteUsesTaoForAlphaSim() throws {
        let apiFactory = makeApiFactory(sim: buySim)
        let factory = SubtensorQuoteOperationFactory(
            operationFactory: apiFactory,
            operationQueue: OperationQueue()
        )

        _ = try fetchQuote(using: factory, args: buyArgs)

        verify(apiFactory, times(1)).createSimSwapTaoForAlphaWrapper(
            netuid: any(),
            taoAmount: any(),
            blockHash: any()
        )
        verify(apiFactory, never()).createSimSwapAlphaForTaoWrapper(
            netuid: any(),
            alphaAmount: any(),
            blockHash: any()
        )
    }

    func testUnstakeQuoteUsesAlphaForTaoSim() throws {
        let apiFactory = makeApiFactory(sim: sellSim)
        let factory = SubtensorQuoteOperationFactory(
            operationFactory: apiFactory,
            operationQueue: OperationQueue()
        )

        _ = try fetchQuote(using: factory, args: sellArgs)

        verify(apiFactory, times(1)).createSimSwapAlphaForTaoWrapper(
            netuid: any(),
            alphaAmount: any(),
            blockHash: any()
        )
        verify(apiFactory, never()).createSimSwapTaoForAlphaWrapper(
            netuid: any(),
            taoAmount: any(),
            blockHash: any()
        )
    }

    func testAllReadsPinnedToFetchedBlockHash() throws {
        let apiFactory = makeApiFactory(sim: buySim)
        let factory = SubtensorQuoteOperationFactory(
            operationFactory: apiFactory,
            operationQueue: OperationQueue()
        )

        _ = try fetchQuote(using: factory, args: buyArgs)

        let simHashCaptor = ArgumentCaptor<BlockHash?>()
        let priceHashCaptor = ArgumentCaptor<BlockHash?>()
        let feeRateHashCaptor = ArgumentCaptor<BlockHash?>()

        verify(apiFactory, times(1)).createSimSwapTaoForAlphaWrapper(
            netuid: equal(to: netuid),
            taoAmount: equal(to: BigUInt(1_000_000_000)),
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

    func testZeroSpotPriceFailsAsMissing() {
        let factory = makeFactory(sim: buySim, spot: 0)

        XCTAssertThrowsError(try fetchQuote(using: factory, args: buyArgs)) { error in
            XCTAssertEqual(error as? SubtensorQuoteError, .missingSpotPrice(netuid: netuid))
        }
    }

    func testZeroAlphaOutOnStakeFailsAsQuoteUnavailable() {
        let factory = makeFactory(sim: makeSim())

        XCTAssertThrowsError(try fetchQuote(using: factory, args: buyArgs)) { error in
            XCTAssertEqual(error as? SubtensorQuoteError, .quoteUnavailable(netuid: netuid))
        }
    }

    func testZeroTaoOutOnUnstakeFailsAsQuoteUnavailable() {
        let factory = makeFactory(sim: makeSim())

        XCTAssertThrowsError(try fetchQuote(using: factory, args: sellArgs)) { error in
            XCTAssertEqual(error as? SubtensorQuoteError, .quoteUnavailable(netuid: netuid))
        }
    }

    func testZeroOutWithNonZeroSlippageStillFailsAsQuoteUnavailable() {
        let factory = makeFactory(sim: makeSim(alphaSlippage: 1_000_000_000))

        XCTAssertThrowsError(try fetchQuote(using: factory, args: buyArgs)) { error in
            XCTAssertEqual(error as? SubtensorQuoteError, .quoteUnavailable(netuid: netuid))
        }
    }

    func testBuyPriceImpactGoldenFromPinnedCapture() throws {
        let quote = try fetchQuote(using: makeFactory(sim: buySim), args: buyArgs)

        let impact = try XCTUnwrap(quote.priceImpact)

        XCTAssertEqual(impact.mul(value: 1_000_000), 80)
    }

    func testSellPriceImpactGoldenFromPinnedCapture() throws {
        let quote = try fetchQuote(using: makeFactory(sim: sellSim), args: sellArgs)

        let impact = try XCTUnwrap(quote.priceImpact)

        XCTAssertEqual(impact.mul(value: 1_000_000), 80)
    }

    func testPriceImpactIsTheSizeOfTheMoveWhenOutBeatsSpotValuation() {
        let quote = SubtensorQuote(
            args: buyArgs,
            sim: makeSim(taoAmount: 1_000_000_000, alphaAmount: 200_000_000_000),
            spotPrice: spotPrice,
            feeRate: 33
        )

        XCTAssertEqual(quote.priceImpact?.mul(value: 1_000_000), 576_503)
    }

    func testPriceImpactNilWhenSimAlphaIsZero() {
        let quote = SubtensorQuote(
            args: buyArgs,
            sim: makeSim(taoAmount: 1_000_000_000),
            spotPrice: spotPrice,
            feeRate: 33
        )

        XCTAssertNil(quote.priceImpact)
    }

    func testBlockHashFailurePropagates() {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createBestBlockHashWrapper()).thenReturn(
                CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
            )
            stubPinnedReads(stub, sim: buySim, spot: spotPrice, feeRate: 33)
        }

        let factory = SubtensorQuoteOperationFactory(
            operationFactory: apiFactory,
            operationQueue: OperationQueue()
        )

        XCTAssertThrowsError(try fetchQuote(using: factory, args: buyArgs))
    }

    func testSimFailurePropagates() {
        let factory = makeFailureFactory(
            simResult: CompoundOperationWrapper.createWithError(CommonError.dataCorruption),
            feeRateResult: CompoundOperationWrapper.createWithResult(33)
        )

        XCTAssertThrowsError(try fetchQuote(using: factory, args: buyArgs))
    }

    func testFeeRateFailurePropagates() {
        let factory = makeFailureFactory(
            simResult: CompoundOperationWrapper.createWithResult(buySim),
            feeRateResult: CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
        )

        XCTAssertThrowsError(try fetchQuote(using: factory, args: buyArgs))
    }

    private func makeSim(
        taoAmount: Balance = 0,
        alphaAmount: Balance = 0,
        taoFee: Balance = 0,
        alphaFee: Balance = 0,
        taoSlippage: Balance = 0,
        alphaSlippage: Balance = 0
    ) -> SubtensorStakingPallet.SimSwapResult {
        SubtensorStakingPallet.SimSwapResult(
            taoAmount: taoAmount,
            alphaAmount: alphaAmount,
            taoFee: taoFee,
            alphaFee: alphaFee,
            taoSlippage: taoSlippage,
            alphaSlippage: alphaSlippage
        )
    }

    private func stubPinnedReads(
        _ stub: MockSubtensorApiOperationFactoryProtocol.Stubbing,
        sim: SubtensorStakingPallet.SimSwapResult,
        spot: Balance,
        feeRate: UInt16
    ) {
        stubPinnedReads(
            stub,
            simResult: CompoundOperationWrapper.createWithResult(sim),
            spot: spot,
            feeRateResult: CompoundOperationWrapper.createWithResult(feeRate)
        )
    }

    private func stubPinnedReads(
        _ stub: MockSubtensorApiOperationFactoryProtocol.Stubbing,
        simResult: CompoundOperationWrapper<SubtensorStakingPallet.SimSwapResult>,
        spot: Balance,
        feeRateResult: CompoundOperationWrapper<UInt16>
    ) {
        when(stub.createSimSwapTaoForAlphaWrapper(netuid: any(), taoAmount: any(), blockHash: any()))
            .thenReturn(simResult)
        when(stub.createSimSwapAlphaForTaoWrapper(netuid: any(), alphaAmount: any(), blockHash: any()))
            .thenReturn(simResult)
        when(stub.createAlphaPriceWrapper(for: any(), blockHash: any())).thenReturn(
            CompoundOperationWrapper.createWithResult(spot)
        )
        when(stub.createFeeRateWrapper(for: any(), blockHash: any())).thenReturn(feeRateResult)
    }

    private func makeApiFactory(
        sim: SubtensorStakingPallet.SimSwapResult,
        spot: Balance? = nil
    ) -> MockSubtensorApiOperationFactoryProtocol {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createBestBlockHashWrapper()).thenReturn(
                CompoundOperationWrapper.createWithResult(bestBlockHash)
            )
            stubPinnedReads(stub, sim: sim, spot: spot ?? spotPrice, feeRate: 33)
        }

        return apiFactory
    }

    private func makeFactory(
        sim: SubtensorStakingPallet.SimSwapResult,
        spot: Balance? = nil
    ) -> SubtensorQuoteOperationFactory {
        SubtensorQuoteOperationFactory(
            operationFactory: makeApiFactory(sim: sim, spot: spot),
            operationQueue: OperationQueue()
        )
    }

    private func makeFailureFactory(
        simResult: CompoundOperationWrapper<SubtensorStakingPallet.SimSwapResult>,
        feeRateResult: CompoundOperationWrapper<UInt16>
    ) -> SubtensorQuoteOperationFactory {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createBestBlockHashWrapper()).thenReturn(
                CompoundOperationWrapper.createWithResult(bestBlockHash)
            )
            stubPinnedReads(
                stub,
                simResult: simResult,
                spot: spotPrice,
                feeRateResult: feeRateResult
            )
        }

        return SubtensorQuoteOperationFactory(
            operationFactory: apiFactory,
            operationQueue: OperationQueue()
        )
    }

    private func fetchQuote(
        using factory: SubtensorQuoteOperationFactory,
        args: SubtensorQuoteArgs
    ) throws -> SubtensorQuote {
        let wrapper = factory.createQuoteWrapper(for: args)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

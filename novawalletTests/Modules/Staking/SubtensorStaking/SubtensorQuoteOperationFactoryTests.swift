import BigInt
import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorQuoteOperationFactoryTests: XCTestCase {
    private let bestBlockHash = "0x1a7d81b7dbe1505dbe063cbecebfc64d0b5a0c39e9bb7a755be17dd9c8fbcd62"
    private let netuid: UInt16 = 1

    func testStakeQuoteMergesSimSpotAndFeeRateReadAtOneBlock() throws {
        let sim = generateSim(taoAmount: 999_496_453, alphaAmount: 130_082_405_209, taoFee: 503_547)
        let args = SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: 1_000_000_000))
        let apiFactory = createApiFactory(sim: sim)

        let quote = try performQuote(using: apiFactory, args: args)

        XCTAssertEqual(quote.sim, sim)
        XCTAssertEqual(quote.spotPrice, BigUInt(7_683_255))
        XCTAssertEqual(quote.feeRate, 33)
        XCTAssertEqual(quote.expectedOut, BigUInt(130_082_405_209))
        XCTAssertEqual(quote.poolFee, BigUInt(503_547))
        XCTAssertEqual(quote.priceImpact?.mul(value: 1_000_000), 80)

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

    func testUnstakeQuoteTakesOutAndFeeFromTheTaoSide() throws {
        let sim = generateSim(
            taoAmount: 998_912_946,
            alphaAmount: 130_016_902_511,
            alphaFee: 65_502_698,
            taoSlippage: 543_368
        )
        let args = SubtensorQuoteArgs(netuid: netuid, direction: .unstake(alphaIn: 130_082_405_209))
        let apiFactory = createApiFactory(sim: sim)

        let quote = try performQuote(using: apiFactory, args: args)

        XCTAssertEqual(quote.expectedOut, BigUInt(998_912_946))
        XCTAssertEqual(quote.poolFee, BigUInt(65_502_698))
        XCTAssertEqual(quote.priceImpact?.mul(value: 1_000_000), 80)
        verify(apiFactory, times(1)).createSimSwapAlphaForTaoWrapper(
            netuid: equal(to: netuid),
            alphaAmount: equal(to: BigUInt(130_082_405_209)),
            blockHash: any()
        )
    }

    func testZeroOutSimFailsAsQuoteUnavailable() {
        let args = SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: 1_000_000_000))
        let apiFactory = createApiFactory(sim: generateSim())

        XCTAssertThrowsError(try performQuote(using: apiFactory, args: args)) { error in
            XCTAssertEqual(error as? SubtensorQuoteError, .quoteUnavailable(netuid: netuid))
        }
    }

    func testLargeBuyPriceImpactIsThePoolPriceMove() throws {
        let sim = generateSim(taoAmount: 1_199_395_742_733, alphaAmount: 16_156_594_429_601, taoFee: 604_257_267)
        let args = SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: 1_200_000_000_000))

        let quote = try performQuote(using: createApiFactory(sim: sim, spot: 73_800_000), args: args)

        XCTAssertEqual(quote.priceImpact?.mul(value: 1_000_000), 11841)
    }

    private func generateSim(
        taoAmount: Balance = 0,
        alphaAmount: Balance = 0,
        taoFee: Balance = 0,
        alphaFee: Balance = 0,
        taoSlippage: Balance = 0
    ) -> SubtensorStakingPallet.SimSwapResult {
        SubtensorStakingPallet.SimSwapResult(
            taoAmount: taoAmount,
            alphaAmount: alphaAmount,
            taoFee: taoFee,
            alphaFee: alphaFee,
            taoSlippage: taoSlippage,
            alphaSlippage: 0
        )
    }

    private func createApiFactory(
        sim: SubtensorStakingPallet.SimSwapResult,
        spot: Balance = 7_683_255
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

    private func performQuote(
        using apiFactory: MockSubtensorApiOperationFactoryProtocol,
        args: SubtensorQuoteArgs
    ) throws -> SubtensorQuote {
        let factory = SubtensorQuoteOperationFactory(operationFactory: apiFactory, operationQueue: OperationQueue())
        let wrapper = factory.createQuoteWrapper(for: args)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

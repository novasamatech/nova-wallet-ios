import BigInt
import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorTradeQuoteFactoryTests: XCTestCase {
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let beneficiary = Data(repeating: 0xBB, count: 32)
    private let netuid: UInt16 = 64
    private let spotPrice: Balance = 73_800_000
    private let tolerance = BigRational(numerator: 5, denominator: 1000)
    private let grossTao: Balance = 5_000_000_000
    private let stakedTao: Balance = 4_957_858_206
    private let soldAlpha: Balance = 56_200_000_000

    func testBuyQuoteSimulatesTheStakeNetOfNovaFee() throws {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()
        let quote = makeBuyQuote(alphaOut: 67_054_958_000)

        stubQuote(quoteFactory, returning: quote)

        let tradeQuote = try run(
            makeFactory(quoteFactory).createBuyQuoteWrapper(netuid: netuid, grossTao: grossTao, tolerance: tolerance)
        )

        let expected = SubtensorTradeQuote(
            quote: quote,
            amountIn: 5_000_000_000,
            novaFee: SubtensorNovaFee(amount: 42_141_794, beneficiary: beneficiary),
            expectedOut: 67_054_958_000,
            swapMinimumOut: 66_811_763_513,
            minimumOut: 66_811_763_513,
            limitPrice: 74_169_000
        )

        XCTAssertEqual(tradeQuote, expected)
        verify(quoteFactory).createQuoteWrapper(
            for: equal(to: SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: 4_957_858_206)))
        )
    }

    func testSellQuoteChargesNovaFeeOnTheQuotedTaoOut() throws {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()
        let quote = makeSellQuote(taoOut: 4_145_000_000)

        stubQuote(quoteFactory, returning: quote)

        let tradeQuote = try run(
            makeFactory(quoteFactory).createSellQuoteWrapper(netuid: netuid, alpha: soldAlpha, tolerance: tolerance)
        )

        let expected = SubtensorTradeQuote(
            quote: quote,
            amountIn: 56_200_000_000,
            novaFee: SubtensorNovaFee(amount: 34_935_547, beneficiary: beneficiary),
            expectedOut: 4_110_064_453,
            swapMinimumOut: 4_124_744_148,
            minimumOut: 4_089_808_601,
            limitPrice: 73_431_000
        )

        XCTAssertEqual(tradeQuote, expected)
    }

    func testSellSwapMinimumIsTheAlphaNetOfPoolFeeAtTheGivenLimitRoundedDown() throws {
        let minimumTaoOut = try SubtensorTradeQuoteFactory.sellSwapMinimumOut(
            alpha: 28_614_410,
            feeRate: 33,
            limitPrice: 69_650_000
        )

        XCTAssertEqual(minimumTaoOut, 1_991_990)
    }

    func testSellQuoteAndSellExtrinsicChargeTheSameNovaFee() throws {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()

        stubQuote(quoteFactory, returning: makeSellQuote(taoOut: 4_145_000_000))

        let tradeQuote = try run(
            makeFactory(quoteFactory).createSellQuoteWrapper(netuid: netuid, alpha: soldAlpha, tolerance: tolerance)
        )

        let operation = SubtensorStakingOperation.subnetSell(
            hotkey: hotkey,
            netuid: netuid,
            alpha: soldAlpha,
            limitPrice: tradeQuote.limitPrice,
            quotedTaoOut: tradeQuote.quote.sim.taoAmount
        )

        let builder = RecordingExtrinsicBuilder()
        _ = try operation.extrinsicBuilderClosure(
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: beneficiary)
        )(builder)

        let feeTransfer = try XCTUnwrap(builder.addedCallArgs.last as? TransferCall)

        XCTAssertEqual(feeTransfer.value, tradeQuote.novaFee?.amount)
    }

    func testBuyQuoteAndBuyExtrinsicChargeTheSameNovaFee() throws {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()

        stubQuote(quoteFactory, returning: makeBuyQuote(alphaOut: 67_054_958_000))

        let tradeQuote = try run(
            makeFactory(quoteFactory).createBuyQuoteWrapper(netuid: netuid, grossTao: grossTao, tolerance: tolerance)
        )

        let operation = SubtensorStakingOperation.subnetBuy(
            hotkey: hotkey,
            netuid: netuid,
            grossTao: grossTao,
            limitPrice: tradeQuote.limitPrice
        )

        let builder = RecordingExtrinsicBuilder()
        _ = try operation.extrinsicBuilderClosure(
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: beneficiary)
        )(builder)

        let stakeCall = try XCTUnwrap(builder.addedCallArgs.first as? SubtensorStakingPallet.AddStakeLimitCall)
        let feeTransfer = try XCTUnwrap(builder.addedCallArgs.last as? TransferCall)

        XCTAssertEqual(feeTransfer.value, tradeQuote.novaFee?.amount)
        XCTAssertEqual(stakeCall.amountStaked, tradeQuote.quote.args.direction.taoIn)
    }

    func testBuyWhosePostTradePriceReachesTheLimitIsNotFillableAlthoughItsAveragePriceIsInside() throws {
        let tradeQuote = try runBuyQuote(alphaOut: 66_964_347_135)
        let sim = tradeQuote.quote.sim
        let averagePrice = sim.taoAmount * SubtensorStakingPallet.alphaPriceScale / sim.alphaAmount

        XCTAssertLessThan(averagePrice, tradeQuote.limitPrice)
        XCTAssertFalse(tradeQuote.isFillable(atLimit: tradeQuote.limitPrice))
    }

    func testBuyWhosePostTradePriceStaysInsideTheLimitIsFillable() throws {
        let tradeQuote = try runBuyQuote(alphaOut: 67_054_958_000)

        XCTAssertTrue(tradeQuote.isFillable(atLimit: tradeQuote.limitPrice))
    }

    func testSellWhosePostTradePriceReachesTheLimitIsNotFillableAlthoughItsAveragePriceIsInside() throws {
        let tradeQuote = try runSellQuote(taoOut: 4_133_000_000)
        let sim = tradeQuote.quote.sim
        let averagePrice = sim.taoAmount * SubtensorStakingPallet.alphaPriceScale / sim.alphaAmount

        XCTAssertGreaterThan(averagePrice, tradeQuote.limitPrice)
        XCTAssertFalse(tradeQuote.isFillable(atLimit: tradeQuote.limitPrice))
    }

    func testSellWhosePostTradePriceStaysInsideTheLimitIsFillable() throws {
        let tradeQuote = try runSellQuote(taoOut: 4_145_000_000)

        XCTAssertTrue(tradeQuote.isFillable(atLimit: tradeQuote.limitPrice))
    }

    func testBuyWhoseRoundedUpPostTradePriceEqualsTheAcceptedLimitIsNotFillable() throws {
        let tradeQuote = try runBuyQuote(alphaOut: 66_978_585_515)

        XCTAssertFalse(tradeQuote.isFillable(atLimit: 74_169_001))
    }

    func testSellWhoseRoundedDownPostTradePriceEqualsTheLimitIsNotFillable() throws {
        let tradeQuote = try runSellQuote(taoOut: 4_135_094_907)

        XCTAssertFalse(tradeQuote.isFillable(atLimit: tradeQuote.limitPrice))
    }

    func testBuyQuoteWithoutBeneficiaryFailsClosed() {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()
        let factory = SubtensorTradeQuoteFactory(
            quoteFactory: quoteFactory,
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: nil)
        )

        XCTAssertThrowsError(
            try run(factory.createBuyQuoteWrapper(netuid: netuid, grossTao: grossTao, tolerance: tolerance))
        ) { error in
            XCTAssertEqual(error as? SubtensorStakingOperationError, .novaFeeUnavailable)
        }
    }

    func testSellQuoteWithoutBeneficiaryFailsClosed() {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()
        let factory = SubtensorTradeQuoteFactory(
            quoteFactory: quoteFactory,
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: nil)
        )

        XCTAssertThrowsError(
            try run(factory.createSellQuoteWrapper(netuid: netuid, alpha: soldAlpha, tolerance: tolerance))
        ) { error in
            XCTAssertEqual(error as? SubtensorStakingOperationError, .novaFeeUnavailable)
        }
    }

    private func makeFactory(_ quoteFactory: MockSubtensorQuoteOperationFactoryProtocol) -> SubtensorTradeQuoteFactory {
        SubtensorTradeQuoteFactory(
            quoteFactory: quoteFactory,
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: beneficiary)
        )
    }

    private func runBuyQuote(alphaOut: Balance) throws -> SubtensorTradeQuote {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()

        stubQuote(quoteFactory, returning: makeBuyQuote(alphaOut: alphaOut))

        return try run(
            makeFactory(quoteFactory).createBuyQuoteWrapper(netuid: netuid, grossTao: grossTao, tolerance: tolerance)
        )
    }

    private func runSellQuote(taoOut: Balance) throws -> SubtensorTradeQuote {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()

        stubQuote(quoteFactory, returning: makeSellQuote(taoOut: taoOut))

        return try run(
            makeFactory(quoteFactory).createSellQuoteWrapper(netuid: netuid, alpha: soldAlpha, tolerance: tolerance)
        )
    }

    private func makeBuyQuote(alphaOut: Balance) -> SubtensorQuote {
        makeQuote(
            direction: .stake(taoIn: stakedTao),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: 4_955_361_688,
                alphaAmount: alphaOut,
                taoFee: 2_496_518,
                alphaFee: 0,
                taoSlippage: 0,
                alphaSlippage: 0
            )
        )
    }

    private func makeSellQuote(taoOut: Balance) -> SubtensorQuote {
        makeQuote(
            direction: .unstake(alphaIn: soldAlpha),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: taoOut,
                alphaAmount: 56_171_700_618,
                taoFee: 0,
                alphaFee: 28_299_382,
                taoSlippage: 0,
                alphaSlippage: 0
            )
        )
    }

    private func makeQuote(
        direction: SubtensorQuoteArgs.Direction,
        sim: SubtensorStakingPallet.SimSwapResult
    ) -> SubtensorQuote {
        SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: netuid, direction: direction),
            sim: sim,
            spotPrice: spotPrice,
            feeRate: 33,
            capturedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
    }

    private func stubQuote(_ quoteFactory: MockSubtensorQuoteOperationFactoryProtocol, returning quote: SubtensorQuote) {
        stub(quoteFactory) { stub in
            when(stub.createQuoteWrapper(for: any())).thenReturn(CompoundOperationWrapper.createWithResult(quote))
        }
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

private extension SubtensorQuoteArgs.Direction {
    var taoIn: Balance? {
        guard case let .stake(taoIn) = self else {
            return nil
        }

        return taoIn
    }
}

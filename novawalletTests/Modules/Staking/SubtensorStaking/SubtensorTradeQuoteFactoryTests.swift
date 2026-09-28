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
    private let spotPrice: Balance = 7_683_225
    private let tolerance = BigRational(numerator: 5, denominator: 1000)

    func testBuyQuoteSimulatesTheStakeNetOfNovaFee() throws {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()
        let quote = makeQuote(direction: .stake(taoIn: 991_571_642), taoAmount: 991_571_642, alphaAmount: 128_800_000_000)

        stubQuote(quoteFactory, returning: quote)

        let tradeQuote = try run(
            makeFactory(quoteFactory).createBuyQuoteWrapper(netuid: netuid, grossTao: 1_000_000_000, tolerance: tolerance)
        )

        let expected = SubtensorTradeQuote(
            quote: quote,
            novaFee: SubtensorNovaFee(amount: 8_428_358, beneficiary: beneficiary),
            expectedOut: 128_800_000_000,
            minimumOut: 128_349_963_304,
            limitPrice: 7_721_641
        )

        XCTAssertEqual(tradeQuote, expected)
        verify(quoteFactory).createQuoteWrapper(
            for: equal(to: SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: 991_571_642)))
        )
    }

    func testSellQuoteChargesNovaFeeOnTheQuotedTaoOut() throws {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()
        let quote = makeQuote(
            direction: .unstake(alphaIn: 500_000_000_000),
            taoAmount: 3_839_000_000,
            alphaAmount: 500_000_000_000
        )

        stubQuote(quoteFactory, returning: quote)

        let tradeQuote = try run(
            makeFactory(quoteFactory).createSellQuoteWrapper(netuid: netuid, alpha: 500_000_000_000, tolerance: tolerance)
        )

        let expected = SubtensorTradeQuote(
            quote: quote,
            novaFee: SubtensorNovaFee(amount: 32_356_470, beneficiary: beneficiary),
            expectedOut: 3_806_643_530,
            minimumOut: 3_788_123_266,
            limitPrice: 7_644_809
        )

        XCTAssertEqual(tradeQuote, expected)
    }

    func testSellQuoteAndSellExtrinsicChargeTheSameNovaFee() throws {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()
        let alpha: Balance = 500_000_000_000

        stubQuote(
            quoteFactory,
            returning: makeQuote(direction: .unstake(alphaIn: alpha), taoAmount: 3_839_000_000, alphaAmount: alpha)
        )

        let tradeQuote = try run(
            makeFactory(quoteFactory).createSellQuoteWrapper(netuid: netuid, alpha: alpha, tolerance: tolerance)
        )

        let operation = SubtensorStakingOperation.subnetSell(
            hotkey: hotkey,
            netuid: netuid,
            alpha: alpha,
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
        let grossTao: Balance = 1_000_000_000

        stubQuote(
            quoteFactory,
            returning: makeQuote(direction: .stake(taoIn: 991_571_642), taoAmount: 991_571_642, alphaAmount: 128_800_000_000)
        )

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

    func testBuyQuoteWithoutBeneficiaryFailsClosed() {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()
        let factory = SubtensorTradeQuoteFactory(
            quoteFactory: quoteFactory,
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: nil)
        )

        XCTAssertThrowsError(
            try run(factory.createBuyQuoteWrapper(netuid: netuid, grossTao: 1_000_000_000, tolerance: tolerance))
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
            try run(factory.createSellQuoteWrapper(netuid: netuid, alpha: 500_000_000_000, tolerance: tolerance))
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

    private func makeQuote(
        direction: SubtensorQuoteArgs.Direction,
        taoAmount: Balance,
        alphaAmount: Balance
    ) -> SubtensorQuote {
        SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: netuid, direction: direction),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: taoAmount,
                alphaAmount: alphaAmount,
                taoFee: 499_303,
                alphaFee: 251_774_052,
                taoSlippage: 0,
                alphaSlippage: 0
            ),
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

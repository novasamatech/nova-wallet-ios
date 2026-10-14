import BigInt
import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorTradeQuoteFactoryTests: XCTestCase {
    private let beneficiary = Data(repeating: 0xBB, count: 32)
    private let netuid: UInt16 = 64
    private let tolerance = BigRational(numerator: 5, denominator: 1000)

    func testBuyQuoteSimulatesTheStakeNetOfNovaFee() throws {
        let quote = generateBuyQuote(alphaOut: 67_054_958_000)
        let quoteFactory = createQuoteFactory(returning: quote)

        let tradeQuote = try run(
            createFactory(quoteFactory: quoteFactory).createBuyQuoteWrapper(
                netuid: netuid,
                grossTao: 5_000_000_000,
                tolerance: tolerance
            )
        )

        let expected = SubtensorTradeQuote(
            quote: quote,
            amountIn: 5_000_000_000,
            novaFee: SubtensorNovaFee(amount: 14_955_134, beneficiary: beneficiary),
            expectedOut: 67_054_958_000,
            swapMinimumOut: 67_178_129_124,
            minimumOut: 67_178_129_124,
            limitPrice: 74_169_000
        )
        XCTAssertEqual(tradeQuote, expected)
        verify(quoteFactory).createQuoteWrapper(
            for: equal(to: SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: 4_985_044_866)))
        )
    }

    func testSellQuoteChargesNovaFeeOnTheQuotedTaoOut() throws {
        let quote = generateSellQuote(taoOut: 4_145_000_000)
        let quoteFactory = createQuoteFactory(returning: quote)

        let tradeQuote = try run(
            createFactory(quoteFactory: quoteFactory).createSellQuoteWrapper(
                netuid: netuid,
                alpha: 56_200_000_000,
                tolerance: tolerance
            )
        )

        let expected = SubtensorTradeQuote(
            quote: quote,
            amountIn: 56_200_000_000,
            novaFee: SubtensorNovaFee(amount: 12_397_806, beneficiary: beneficiary),
            expectedOut: 4_132_602_194,
            swapMinimumOut: 4_124_744_148,
            minimumOut: 4_112_346_342,
            limitPrice: 73_431_000
        )
        XCTAssertEqual(tradeQuote, expected)
    }

    func testBuyWhosePostTradePriceReachesTheLimitIsNotFillable() throws {
        let quoteFactory = createQuoteFactory(returning: generateBuyQuote(alphaOut: 66_964_347_135))

        let tradeQuote = try run(
            createFactory(quoteFactory: quoteFactory).createBuyQuoteWrapper(
                netuid: netuid,
                grossTao: 5_000_000_000,
                tolerance: tolerance
            )
        )

        XCTAssertFalse(tradeQuote.isFillable(atLimit: tradeQuote.limitPrice))
    }

    func testBuyQuoteWithoutBeneficiaryFailsClosed() {
        let factory = SubtensorTradeQuoteFactory(
            quoteFactory: MockSubtensorQuoteOperationFactoryProtocol(),
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: nil)
        )

        XCTAssertThrowsError(
            try run(factory.createBuyQuoteWrapper(netuid: netuid, grossTao: 5_000_000_000, tolerance: tolerance))
        ) { error in
            XCTAssertEqual(error as? SubtensorStakingOperationError, .novaFeeUnavailable)
        }
    }

    private func createFactory(quoteFactory: MockSubtensorQuoteOperationFactoryProtocol) -> SubtensorTradeQuoteFactory {
        SubtensorTradeQuoteFactory(
            quoteFactory: quoteFactory,
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: beneficiary)
        )
    }

    private func createQuoteFactory(returning quote: SubtensorQuote) -> MockSubtensorQuoteOperationFactoryProtocol {
        let quoteFactory = MockSubtensorQuoteOperationFactoryProtocol()

        stub(quoteFactory) { stub in
            when(stub.createQuoteWrapper(for: any())).thenReturn(CompoundOperationWrapper.createWithResult(quote))
        }

        return quoteFactory
    }

    private func generateBuyQuote(alphaOut: Balance) -> SubtensorQuote {
        generateQuote(
            direction: .stake(taoIn: 4_985_044_866),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: 4_955_361_688,
                alphaAmount: alphaOut,
                taoFee: 2_496_518,
                alphaFee: 0
            )
        )
    }

    private func generateSellQuote(taoOut: Balance) -> SubtensorQuote {
        generateQuote(
            direction: .unstake(alphaIn: 56_200_000_000),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: taoOut,
                alphaAmount: 56_171_700_618,
                taoFee: 0,
                alphaFee: 28_299_382
            )
        )
    }

    private func generateQuote(
        direction: SubtensorQuoteArgs.Direction,
        sim: SubtensorStakingPallet.SimSwapResult
    ) -> SubtensorQuote {
        SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: netuid, direction: direction),
            sim: sim,
            spotPrice: 73_800_000,
            feeRate: 33,
            capturedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

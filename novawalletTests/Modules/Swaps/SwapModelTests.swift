import XCTest
@testable import novawallet
import BigInt

final class SwapModelTests: XCTestCase {
    func testCanReceiveUsesNetAmount() throws {
        let chargingModel = try makeModel(
            quoteAmountOut: 1_000_000,
            commission: CommissionTestFixtures.makeCommission(),
            receiveBalance: 0,
            receiveMinBalance: 995_000
        )

        guard case .existense = chargingModel.checkReceiveBalanceAboveMin() else {
            XCTFail("expected .existense when the net amount is below the minimum")
            return
        }

        let noCommissionModel = try makeModel(
            quoteAmountOut: 1_000_000,
            commission: nil,
            receiveBalance: 0,
            receiveMinBalance: 995_000
        )

        XCTAssertNil(noCommissionModel.checkReceiveBalanceAboveMin())
    }

    func testNetAmountOutEqualsGrossWithoutCommission() throws {
        let model = try makeModel(
            quoteAmountOut: 1_000_000,
            commission: nil,
            receiveBalance: 0,
            receiveMinBalance: 0
        )

        XCTAssertEqual(model.netAmountOut, model.grossAmountOut)
        XCTAssertEqual(model.netAmountOut, 1_000_000)
    }

    func testReceiveEdCheckAccountsForSlippage() throws {
        let noSlippageModel = try makeModel(
            quoteAmountOut: 1_010_000,
            commission: CommissionTestFixtures.makeCommission(),
            receiveBalance: 0,
            receiveMinBalance: 1_000_000
        )

        XCTAssertNil(noSlippageModel.checkReceiveBalanceAboveMin())

        let slippageModel = try makeModel(
            quoteAmountOut: 1_010_000,
            commission: CommissionTestFixtures.makeCommission(),
            receiveBalance: 0,
            receiveMinBalance: 1_000_000,
            slippage: BigRational(numerator: 1, denominator: 100)
        )

        XCTAssertEqual(slippageModel.worstCaseNetAmountOut, 991_401)

        guard case .existense = slippageModel.checkReceiveBalanceAboveMin() else {
            XCTFail("expected .existense when the worst case fill lands below the minimum")
            return
        }
    }
}

private extension SwapModelTests {
    func makeFee(commission: AssetExchangeCommission?) -> AssetExchangeFee {
        AssetExchangeFee(
            route: CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000),
            operationFees: [],
            intermediateFeesInAssetIn: 0,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: commission
        )
    }

    func makeModel(
        quoteAmountOut: Balance,
        commission: AssetExchangeCommission?,
        receiveBalance: Balance,
        receiveMinBalance: Balance,
        slippage: BigRational = BigRational(numerator: 0, denominator: 100)
    ) throws -> SwapModel {
        try makeModel(
            quoteAmountOut: quoteAmountOut,
            fee: makeFee(commission: commission),
            receiveBalance: receiveBalance,
            receiveMinBalance: receiveMinBalance,
            slippage: slippage
        )
    }

    func makeModel(
        quoteAmountOut: Balance,
        fee: AssetExchangeFee,
        receiveBalance: Balance,
        receiveMinBalance: Balance,
        slippage: BigRational = BigRational(numerator: 0, denominator: 100)
    ) throws -> SwapModel {
        let payChainAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveChainAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))

        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: quoteAmountOut)
        let quote = AssetExchangeQuote(route: route, metaOperations: [], executionTimes: [])

        let quoteArgs = AssetConversion.QuoteArgs(
            assetIn: payChainAsset.chainAssetId,
            assetOut: receiveChainAsset.chainAssetId,
            amount: quoteAmountOut,
            direction: .sell
        )

        let receiveAssetBalance = AssetBalance(
            chainAssetId: receiveChainAsset.chainAssetId,
            accountId: CommissionTestFixtures.beneficiary,
            freeInPlank: receiveBalance,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .regular,
            blocked: false
        )

        return SwapModel(
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            feeChainAsset: payChainAsset,
            spendingAmount: nil,
            payAssetBalance: nil,
            feeAssetBalance: nil,
            receiveAssetBalance: receiveAssetBalance,
            utilityAssetBalance: nil,
            payAssetExistense: nil,
            receiveAssetExistense: AssetBalanceExistence(minBalance: receiveMinBalance, isSelfSufficient: true),
            feeAssetExistense: nil,
            utilityAssetExistense: nil,
            feeModel: fee,
            quoteArgs: quoteArgs,
            quote: quote,
            slippage: slippage,
            accountInfo: nil,
            destAccountInfo: nil,
            destUtilityAssetExistence: nil
        )
    }
}

import XCTest
@testable import novawallet
import BigInt

final class SwapModelTests: XCTestCase {
    func testCanReceiveUsesNetAmount() throws {
        let chargingModel = try makeModel(
            quoteAmountOut: 1_000_000,
            commission: CommissionTestFixtures.makeCommission(
                chargingEdgeIndex: 0,
                amount: 8428
            ),
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

    func testSingleOperationExactOutBuyGetsNoSlippageHaircut() throws {
        let model = try makeModel(
            quoteAmountOut: 1_010_000,
            commission: CommissionTestFixtures.makeCommission(
                chargingEdgeIndex: 0,
                amount: 8512
            ),
            receiveBalance: 0,
            receiveMinBalance: 1_000_000,
            slippage: BigRational(numerator: 1, denominator: 100),
            direction: .buy,
            metaOperationCount: 1
        )

        XCTAssertEqual(model.worstCaseNetAmountOut, model.netAmountOut)
        XCTAssertNil(model.checkReceiveBalanceAboveMin())
    }

    func testMultiOperationBuyStillGetsSlippageHaircut() throws {
        let model = try makeModel(
            quoteAmountOut: 1_010_000,
            commission: CommissionTestFixtures.makeCommission(
                chargingEdgeIndex: 0,
                amount: 8512
            ),
            receiveBalance: 0,
            receiveMinBalance: 1_000_000,
            slippage: BigRational(numerator: 1, denominator: 100),
            direction: .buy,
            metaOperationCount: 2
        )

        XCTAssertEqual(model.worstCaseNetAmountOut, 991_474)
        guard case .existense = model.checkReceiveBalanceAboveMin() else {
            return XCTFail("expected .existense when the worst case fill lands below the minimum")
        }
    }

    func testReceiveEdCheckAccountsForSlippage() throws {
        let noSlippageModel = try makeModel(
            quoteAmountOut: 1_010_000,
            commission: CommissionTestFixtures.makeCommission(
                chargingEdgeIndex: 0,
                amount: 8512
            ),
            receiveBalance: 0,
            receiveMinBalance: 1_000_000
        )

        XCTAssertNil(noSlippageModel.checkReceiveBalanceAboveMin())

        let slippageModel = try makeModel(
            quoteAmountOut: 1_010_000,
            commission: CommissionTestFixtures.makeCommission(
                chargingEdgeIndex: 0,
                amount: 8512
            ),
            receiveBalance: 0,
            receiveMinBalance: 1_000_000,
            slippage: BigRational(numerator: 1, denominator: 100)
        )

        XCTAssertEqual(slippageModel.worstCaseNetAmountOut, 991_474)

        guard case .existense = slippageModel.checkReceiveBalanceAboveMin() else {
            XCTFail("expected .existense when the worst case fill lands below the minimum")
            return
        }
    }

    func testCollateralLimitBelowBalanceOffersLimitMinusFee() throws {
        let model = try makeCollateralModel(balance: 100_000, limit: 50000, feeInPayAsset: 6000, spending: 60000)

        guard case let .collateralInUse(reason) = model.checkBalanceSufficiency() else {
            return XCTFail("expected .collateralInUse when the limit is below the balance")
        }

        XCTAssertEqual(reason.available, Balance(44000).decimal(precision: model.payChainAsset.asset.precision))
    }

    func testCollateralLimitBelowBalanceLeavesFeeCheckWhenFeeTakesWholeBalance() throws {
        let model = try makeCollateralModel(balance: 5000, limit: 4000, feeInPayAsset: 6000, spending: 3000)

        guard case .feeInPayAsset = model.checkBalanceSufficiency() else {
            return XCTFail("expected .feeInPayAsset when the fee takes the whole balance")
        }
    }

    func testCollateralLimitAboveBalanceLeavesBalanceCheckToReport() throws {
        let model = try makeCollateralModel(balance: 100_000, limit: 105_000, feeInPayAsset: 6000, spending: 100_000)

        guard case .feeInPayAsset = model.checkBalanceSufficiency() else {
            return XCTFail("expected .feeInPayAsset when the balance is below the limit")
        }
    }

    func testHydraATokenRemainderBelowMinBalanceIsNotDust() throws {
        let model = try makeHydraModel(payAssetId: 2, receiveAssetId: 1, providers: 1)

        XCTAssertNil(model.checkDustAfterSwap())
    }

    func testSwapTakingLastProviderIntoHydraATokenCannotReceive() throws {
        let model = try makeHydraModel(payAssetId: 1, receiveAssetId: 2, providers: 1)

        guard case .noProvider = model.checkCanReceive() else {
            return XCTFail("expected .noProvider when the pay asset was the only provider")
        }
    }

    func testSwapIntoHydraATokenKeepingAnotherProviderCanReceive() throws {
        let model = try makeHydraModel(payAssetId: 1, receiveAssetId: 2, providers: 2)

        XCTAssertNil(model.checkCanReceive())
    }
}

private extension SwapModelTests {
    func makeHydraChain() throws -> ChainModel {
        let json = """
        {"chainId": "\(KnowChainId.hydra)", "name": "Hydration", "addressPrefix": 63, "nodes": [],
        "options": ["hydradx-swaps"], "assets": [{"assetId": 0, "symbol": "HDX", "precision": 12},
        {"assetId": 1, "symbol": "DOT", "precision": 10, "type": "orml"},
        {"assetId": 2, "symbol": "aDOT", "precision": 10, "type": "orml-hydration-evm"}]}
        """
        let remoteChain = try JSONDecoder().decode(RemoteChainModel.self, from: Data(json.utf8))

        return try XCTUnwrap(
            ChainModelConverter().update(localModel: nil, remoteModel: remoteChain, additionalAssets: [], order: 0)
        )
    }

    func makeHydraModel(payAssetId: AssetModel.Id, receiveAssetId: AssetModel.Id, providers: UInt32) throws -> SwapModel {
        let chain = try makeHydraChain()
        let payChainAsset = try XCTUnwrap(chain.chainAsset(for: payAssetId))
        let receiveChainAsset = try XCTUnwrap(chain.chainAsset(for: receiveAssetId))
        let spending: Balance = 9_033_734_111

        return SwapModel(
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            feeChainAsset: payChainAsset,
            spendingAmount: spending.decimal(precision: payChainAsset.asset.precision),
            payAssetBalance: AssetBalance(
                chainAssetId: payChainAsset.chainAssetId,
                accountId: CommissionTestFixtures.beneficiary,
                freeInPlank: 9_037_107_880,
                reservedInPlank: 0,
                frozenInPlank: 0,
                edCountMode: .basedOnTotal,
                transferrableMode: .regular,
                blocked: false
            ),
            feeAssetBalance: nil,
            receiveAssetBalance: nil,
            utilityAssetBalance: nil,
            payAssetExistense: AssetBalanceExistence(minBalance: 17_540_000, isSelfSufficient: true),
            receiveAssetExistense: AssetBalanceExistence(minBalance: 0, isSelfSufficient: true),
            feeAssetExistense: nil,
            utilityAssetExistense: nil,
            feeModel: makeFee(commission: nil),
            quoteArgs: AssetConversion.QuoteArgs(
                assetIn: payChainAsset.chainAssetId,
                assetOut: receiveChainAsset.chainAssetId,
                amount: spending,
                direction: .sell
            ),
            quote: nil,
            slippage: BigRational(numerator: 0, denominator: 100),
            accountInfo: AccountInfo(nonce: 0, providers: providers, sufficients: 0, data: AccountData(free: 0, reserved: 0)),
            destAccountInfo: nil,
            destUtilityAssetExistence: nil,
            payAssetCollateralLimit: nil
        )
    }

    func makeCollateralModel(
        balance: Balance,
        limit: Balance,
        feeInPayAsset: Balance,
        spending: Balance
    ) throws -> SwapModel {
        let payChainAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveChainAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))

        let payAssetBalance = AssetBalance(
            chainAssetId: payChainAsset.chainAssetId,
            accountId: CommissionTestFixtures.beneficiary,
            freeInPlank: balance,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .regular,
            blocked: false
        )

        let fee = AssetExchangeFee(
            route: CommissionTestFixtures.createRoute([.hydraSwap], amount: spending),
            operationFees: [
                AssetExchangeOperationFee(
                    submissionFee: .init(
                        amountWithAsset: .init(amount: feeInPayAsset, asset: payChainAsset.chainAssetId),
                        payer: nil,
                        weight: .init(refTime: 0, proofSize: 0)
                    ),
                    postSubmissionFee: .init(paidByAccount: [], paidFromAmount: [])
                )
            ],
            intermediateFeesInAssetIn: 0,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: payChainAsset.chainAssetId,
            commission: nil
        )

        return SwapModel(
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            feeChainAsset: payChainAsset,
            spendingAmount: spending.decimal(precision: payChainAsset.asset.precision),
            payAssetBalance: payAssetBalance,
            feeAssetBalance: payAssetBalance,
            receiveAssetBalance: nil,
            utilityAssetBalance: nil,
            payAssetExistense: nil,
            receiveAssetExistense: nil,
            feeAssetExistense: nil,
            utilityAssetExistense: nil,
            feeModel: fee,
            quoteArgs: AssetConversion.QuoteArgs(
                assetIn: payChainAsset.chainAssetId,
                assetOut: receiveChainAsset.chainAssetId,
                amount: spending,
                direction: .sell
            ),
            quote: nil,
            slippage: BigRational(numerator: 0, denominator: 100),
            accountInfo: nil,
            destAccountInfo: nil,
            destUtilityAssetExistence: nil,
            payAssetCollateralLimit: .limited(limit)
        )
    }

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
        slippage: BigRational = BigRational(numerator: 0, denominator: 100),
        direction: AssetConversion.Direction = .sell,
        metaOperationCount: Int = 1
    ) throws -> SwapModel {
        try makeModel(
            quoteAmountOut: quoteAmountOut,
            fee: makeFee(commission: commission),
            receiveBalance: receiveBalance,
            receiveMinBalance: receiveMinBalance,
            slippage: slippage,
            direction: direction,
            metaOperationCount: metaOperationCount
        )
    }

    func makeModel(
        quoteAmountOut: Balance,
        fee: AssetExchangeFee,
        receiveBalance: Balance,
        receiveMinBalance: Balance,
        slippage: BigRational = BigRational(numerator: 0, denominator: 100),
        direction: AssetConversion.Direction = .sell,
        metaOperationCount: Int = 1
    ) throws -> SwapModel {
        let payChainAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 0))
        let receiveChainAsset = try XCTUnwrap(CommissionTestFixtures.chain.chainAsset(for: 1))

        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: quoteAmountOut)
        let metaOperations: [AssetExchangeMetaOperationProtocol] = (0 ..< metaOperationCount).map { _ in
            StubAssetExchangeMetaOperation(
                assetIn: payChainAsset,
                assetOut: receiveChainAsset,
                amountIn: quoteAmountOut,
                amountOut: quoteAmountOut
            )
        }
        let quote = AssetExchangeQuote(
            route: route,
            metaOperations: metaOperations,
            metaOperationIndexByEdge: [0],
            executionTimes: [],
            commission: fee.commission
        )

        let quoteArgs = AssetConversion.QuoteArgs(
            assetIn: payChainAsset.chainAssetId,
            assetOut: receiveChainAsset.chainAssetId,
            amount: quoteAmountOut,
            direction: direction
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
            destUtilityAssetExistence: nil,
            payAssetCollateralLimit: nil
        )
    }
}

private final class StubAssetExchangeMetaOperation: AssetExchangeBaseMetaOperation, AssetExchangeMetaOperationProtocol {
    var label: AssetExchangeMetaOperationLabel {
        .swap
    }

    var requiresOriginAccountKeepAlive: Bool {
        false
    }
}

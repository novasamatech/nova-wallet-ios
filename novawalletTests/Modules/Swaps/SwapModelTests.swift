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

    func testBalanceChecksUnchangedByCommission() throws {
        let feeWithCommission = makeFee(commission: CommissionTestFixtures.makeCommission())
        let feeWithoutCommission = makeFee(commission: nil)

        let modelWithCommission = try makeModel(
            quoteAmountOut: 1_000_000,
            fee: feeWithCommission,
            receiveBalance: 0,
            receiveMinBalance: 0
        )
        let modelWithoutCommission = try makeModel(
            quoteAmountOut: 1_000_000,
            fee: feeWithoutCommission,
            receiveBalance: 0,
            receiveMinBalance: 0
        )

        XCTAssertEqual(
            modelWithCommission.payAssetTotalBalanceAfterSwap,
            modelWithoutCommission.payAssetTotalBalanceAfterSwap
        )

        XCTAssertEqual(
            insufficiencyDescription(modelWithCommission.checkEnoughBalanceToSpendAndPayFee()),
            insufficiencyDescription(modelWithoutCommission.checkEnoughBalanceToSpendAndPayFee())
        )
    }

    func testIntermediateEdAlertReportsTheComparedAmount() throws {
        let checkValue = try runIntermediateEdCheck(chargingOperationIndex: 1)

        XCTAssertEqual(checkValue?.comparedAmount, 991_500)
    }

    func testIntermediateEdUsesNetFromChargingSegment() throws {
        let chargingCheck = try runIntermediateEdCheck(chargingOperationIndex: 1)

        XCTAssertEqual(chargingCheck?.operationIndex, 1)

        let noCommissionCheck = try runIntermediateEdCheck(chargingOperationIndex: nil)

        XCTAssertNil(noCommissionCheck)
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
        receiveMinBalance: Balance
    ) throws -> SwapModel {
        try makeModel(
            quoteAmountOut: quoteAmountOut,
            fee: makeFee(commission: commission),
            receiveBalance: receiveBalance,
            receiveMinBalance: receiveMinBalance
        )
    }

    func makeModel(
        quoteAmountOut: Balance,
        fee: AssetExchangeFee,
        receiveBalance: Balance,
        receiveMinBalance: Balance
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
            slippage: BigRational(numerator: 0, denominator: 100),
            accountInfo: nil,
            destAccountInfo: nil,
            destUtilityAssetExistence: nil
        )
    }

    /// `SwapModel.InsufficientBalanceReason` is not `Equatable`, so this projects it to a
    /// comparable `String` the same way the display layer's non-`Equatable` view models are
    /// compared in tests.
    func insufficiencyDescription(_ reason: SwapModel.InsufficientBalanceReason?) -> String? {
        guard let reason else {
            return nil
        }

        switch reason {
        case let .amountToHigh(model):
            return "amountToHigh:\(model.available)"
        case let .feeInNativeAsset(model):
            return "feeInNativeAsset:\(model.available):\(model.fee)"
        case let .feeInPayAsset(model):
            return "feeInPayAsset:\(model.available):\(model.feeInPayAsset)"
        case let .deliveryFee(model):
            return "deliveryFee:\(model.minBalance)"
        case let .originKeepAlive(model):
            return "originKeepAlive:\(model.minBalance)"
        case let .violatingConsumers(model):
            return "violatingConsumers:\(model.minBalance):\(model.fee)"
        }
    }

    /// Drives `SwapBaseInteractor.requestValidatingIntermediateED` through a real interactor with
    /// three operations of shape `[crossChain, hydraSwap, crossChain]`, each `amountOut == 1_000_000`.
    /// `chargingOperationIndex` of `1` charges the middle (`hydraSwap`) operation; `nil` charges nothing.
    func runIntermediateEdCheck(chargingOperationIndex: Int?) throws -> SwapInterEDNotMet? {
        let interactor = CommissionTestFixtures.makeInteractor(
            assetStorageFactory: CountingAssetStorageInfoFactory(
                storageInfoResult: .success(CommissionTestFixtures.ormlInfo(existentialDeposit: 995_000)),
                minBalance: 995_000
            )
        )

        let chain = CommissionTestFixtures.chain
        let operations = try (0 ..< 2).map { index -> AssetExchangeMetaOperationProtocol in
            StubMetaOperation(
                assetIn: try XCTUnwrap(chain.chainAsset(for: AssetModel.Id(index))),
                assetOut: try XCTUnwrap(chain.chainAsset(for: AssetModel.Id(index + 1))),
                amountIn: 1_000_000,
                amountOut: 1_000_000
            )
        }

        let commission = chargingOperationIndex.map {
            AssetExchangeCommission(
                chargingOperationIndex: $0,
                asset: CommissionTestFixtures.asset(2),
                estimatedAmount: 8_500,
                beneficiary: CommissionTestFixtures.beneficiary,
                rate: AssetExchangeCommissionConstants.rate
            )
        }

        var result: SwapInterEDNotMet??
        let expectation = expectation(description: "intermediate ED check")

        interactor.requestValidatingIntermediateED(for: operations, commission: commission) { checkValue in
            result = checkValue
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        return try XCTUnwrap(result)
    }
}

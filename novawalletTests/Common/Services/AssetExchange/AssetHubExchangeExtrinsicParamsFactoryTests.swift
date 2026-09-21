import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import BigInt

final class AssetHubExchangeExtrinsicParamsFactoryTests: XCTestCase {
    func testSellKeepsGrossPalletBoundSoNetMinimumIsDelivered() throws {
        let params = try createParams(
            direction: .sell,
            amountIn: 500_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 1, denominator: 100),
            commissionAmount: 8428
        )

        guard case let .exactIn(call) = params.swap else {
            return XCTFail("exact in call expected")
        }

        XCTAssertEqual(call.amountIn, 500_000)
        XCTAssertEqual(call.amountOutMin, 981_657 + 8428)
        XCTAssertEqual(params.commission?.amount, 8428)
        XCTAssertFalse(call.keepAlive)
    }

    func testBuyKeepsGrossTargetAndUnchangedInputBound() throws {
        let params = try createParams(
            direction: .buy,
            amountIn: 500_000,
            amountOut: 1_008_500,
            slippage: BigRational(numerator: 1, denominator: 100),
            commissionAmount: 8500
        )

        guard case let .exactOut(call) = params.swap else {
            return XCTFail("exact out call expected")
        }

        XCTAssertEqual(call.amountOut, 1_008_500)
        XCTAssertEqual(call.amountInMax, 505_000)
        XCTAssertEqual(params.commission?.amount, 8500)
    }

    func testUnchargedSellBoundIsUnchanged() throws {
        let params = try createParams(
            direction: .sell,
            amountIn: 500_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 1, denominator: 100),
            commissionAmount: nil
        )

        guard case let .exactIn(call) = params.swap else {
            return XCTFail("exact in call expected")
        }

        XCTAssertEqual(call.amountOutMin, 990_000)
        XCTAssertNil(params.commission)
    }

    func testRejectsInvalidSlippage() throws {
        for slippage in [BigRational(numerator: 1, denominator: 0), BigRational(numerator: 3, denominator: 2)] {
            XCTAssertThrowsError(
                try createParams(
                    direction: .sell,
                    amountIn: 500_000,
                    amountOut: 1_000_000,
                    slippage: slippage,
                    commissionAmount: nil
                )
            ) { error in
                XCTAssertEqual(error as? AssetHubExchangePreparationError, .invalidSlippage)
            }
        }
    }

    func testRejectsCommissionNotSmallerThanOutput() throws {
        XCTAssertThrowsError(
            try createParams(
                direction: .sell,
                amountIn: 500_000,
                amountOut: 1_000_000,
                slippage: BigRational(numerator: 0, denominator: 100),
                commissionAmount: 1_000_000
            )
        ) { error in
            XCTAssertEqual(error as? AssetHubExchangePreparationError, .invalidCommission)
        }
    }

    func testRejectsCommissionToSwapReceiver() throws {
        XCTAssertThrowsError(
            try createParams(
                direction: .sell,
                amountIn: 500_000,
                amountOut: 1_000_000,
                slippage: BigRational(numerator: 0, denominator: 100),
                commissionAmount: 8428,
                beneficiary: Self.receiver
            )
        ) { error in
            XCTAssertEqual(error as? AssetHubExchangePreparationError, .invalidCommission)
        }
    }

    func testRejectsNetOutputBelowMinimumBalance() throws {
        XCTAssertThrowsError(
            try createParams(
                direction: .sell,
                amountIn: 500_000,
                amountOut: 1_000_000,
                slippage: BigRational(numerator: 0, denominator: 100),
                commissionAmount: 8428,
                minimumBalance: 1_000_000
            )
        ) { error in
            XCTAssertEqual(error as? AssetHubExchangePreparationError, .netOutputBelowMinimum)
        }
    }

    func testChargedOperationIsSealedIntoSingleAtomicBatch() throws {
        let params = try createParams(
            direction: .sell,
            amountIn: 500_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100),
            commissionAmount: 8428
        )

        let builder = try AssetHubExchangeExtrinsicConverter.addingOperation(
            from: params,
            builder: makeBuilder(for: params)
        )

        let context = params.codingFactory.createRuntimeJsonContext()
        let calls = builder.getCalls()

        XCTAssertEqual(calls.count, 1)

        let batch = try ExtrinsicExtraction.getCall(from: try XCTUnwrap(calls.first), context: context)
        XCTAssertEqual(batch.path, UtilityPallet.batchAllPath)

        let batchArgs: UtilityPallet.Call = try ExtrinsicExtraction.getCallArgs(
            from: batch.args,
            context: context
        )

        XCTAssertEqual(batchArgs.calls.count, 2)
        XCTAssertEqual(batchArgs.calls.first?.path, AssetConversionPallet.swapExactTokenForTokensPath)
        XCTAssertEqual(batchArgs.calls.last?.path, CallCodingPath.transferKeepAlive)

        let transfer: TransferCall = try ExtrinsicExtraction.getCallArgs(
            from: try XCTUnwrap(batchArgs.calls.last).args,
            context: context
        )

        XCTAssertEqual(transfer.value, 8428)
        XCTAssertEqual(transfer.dest.accountId, Self.beneficiary)
    }

    func testUnchargedOperationStaysSingleCall() throws {
        let params = try createParams(
            direction: .sell,
            amountIn: 500_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100),
            commissionAmount: nil
        )

        let builder = try AssetHubExchangeExtrinsicConverter.addingOperation(
            from: params,
            builder: makeBuilder(for: params)
        )

        let context = params.codingFactory.createRuntimeJsonContext()
        let calls = builder.getCalls()

        XCTAssertEqual(calls.count, 1)

        let call = try ExtrinsicExtraction.getCall(from: try XCTUnwrap(calls.first), context: context)
        XCTAssertEqual(call.path, AssetConversionPallet.swapExactTokenForTokensPath)
    }

    func testChargedOperationRejectsNonEmptyBuilder() throws {
        let params = try createParams(
            direction: .sell,
            amountIn: 500_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100),
            commissionAmount: 8428
        )

        let occupiedBuilder = try makeBuilder(for: params).adding(
            call: SubstrateCallFactory().nativeTransfer(
                to: Self.receiver,
                amount: 1,
                callPath: .transferKeepAlive
            )
        )

        XCTAssertThrowsError(
            try AssetHubExchangeExtrinsicConverter.addingOperation(from: params, builder: occupiedBuilder)
        ) { error in
            XCTAssertEqual(error as? AssetHubExchangeBuilderError, .nonEmptyBuilder)
        }
    }
}

private extension AssetHubExchangeExtrinsicParamsFactoryTests {
    /// Mirrors the production builder, which carries the runtime json context before calls are added.
    func makeBuilder(for params: AssetHubExchangeSwapParams) -> ExtrinsicBuilderProtocol {
        ExtrinsicBuilder().with(runtimeJsonContext: params.codingFactory.createRuntimeJsonContext())
    }

    static let receiver = AccountId(repeating: 5, count: 32)
    static let beneficiary = AccountId(repeating: 7, count: 32)

    static let chain = ChainModelGenerator.generateChain(
        defaultChainId: KnowChainId.westmint,
        generatingAssets: 2,
        addressPrefix: 2
    )

    func createParams(
        direction: AssetConversion.Direction,
        amountIn: Balance,
        amountOut: Balance,
        slippage: BigRational,
        commissionAmount: Balance?,
        beneficiary: AccountId = AssetHubExchangeExtrinsicParamsFactoryTests.beneficiary,
        minimumBalance: Balance = 1
    ) throws -> AssetHubExchangeSwapParams {
        let chain = Self.chain
        let assetOut = ChainAssetId(chainId: chain.chainId, assetId: 1)

        let commission = commissionAmount.map { amount in
            AssetExchangeCommission(
                chargingEdgeIndex: 0,
                asset: assetOut,
                amount: amount,
                beneficiary: beneficiary
            )
        }

        let factory = AssetHubExchangeExtrinsicParamsFactory(
            chain: chain,
            runtimeProvider: try RuntimeCodingServiceStub.createWestendService(),
            assetStorageInfoFactory: StubAssetStorageInfoFactory(),
            recipientFactory: StubCommissionRecipientFactory(minimumBalance: minimumBalance),
            operationQueue: OperationQueue()
        )

        let wrapper = factory.createOperationWrapper(
            callArgs: .init(
                assetIn: ChainAssetId(chainId: chain.chainId, assetId: 0),
                amountIn: amountIn,
                assetOut: assetOut,
                amountOut: amountOut,
                receiver: Self.receiver,
                direction: direction,
                slippage: slippage
            ),
            commission: commission
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

private final class StubCommissionRecipientFactory: AssetHubExchangeCommissionRecipientFactoryProtocol {
    let minimumBalance: Balance

    init(minimumBalance: Balance) {
        self.minimumBalance = minimumBalance
    }

    func createMinimumBalanceWrapper(
        recipient _: AccountId,
        storageInfo _: AssetStorageInfo
    ) -> CompoundOperationWrapper<Balance> {
        .createWithResult(minimumBalance)
    }
}

private final class StubAssetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol {
    func createStorageInfoWrapper(
        from _: AssetModel,
        runtimeProvider _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetStorageInfo> {
        .createWithResult(CommissionTestFixtures.nativeInfo())
    }

    func createAssetBalanceExistenceOperation(
        for _: AssetStorageInfo,
        chainId _: ChainModel.Id,
        asset _: AssetModel
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        .createWithResult(AssetBalanceExistence(minBalance: 1, isSelfSufficient: true))
    }
}

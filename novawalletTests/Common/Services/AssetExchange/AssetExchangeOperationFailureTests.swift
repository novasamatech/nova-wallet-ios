import XCTest
import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import BigInt

final class AssetExchangeOperationFailureTests: XCTestCase {
    func testHydraHopFailedAfterSubmissionReportsSubmittedTxHash() throws {
        let operation = try createHydraOperation(submitMonitor: createDispatchFailingSubmitMonitor())

        let failure = try performFailingHop(operation.executeWrapper(for: Self.swapLimit))

        XCTAssertEqual(failure.stage, .submitted(txHash: Self.txHash))
        XCTAssertTrue(failure.error is DispatchCallError)
    }

    func testHydraHopFailedBeforeSubmissionReportsNoTxHash() throws {
        let operation = try createHydraOperation(submitMonitor: createRejectingSubmitMonitor())

        let failure = try performFailingHop(operation.executeWrapper(for: Self.swapLimit))

        XCTAssertEqual(failure.stage, .notSubmitted)
        XCTAssertEqual(failure.error as? JSONRPCEngineError, .clientCancelled)
    }

    func testAssetHubHopFailedAfterSubmissionReportsSubmittedTxHash() throws {
        let operation = try createAssetHubOperation(submitMonitor: createDispatchFailingSubmitMonitor())

        let failure = try performFailingHop(operation.executeWrapper(for: Self.swapLimit))

        XCTAssertEqual(failure.stage, .submitted(txHash: Self.txHash))
        XCTAssertTrue(failure.error is DispatchCallError)
    }

    func testAssetHubHopFailedBeforeSubmissionReportsNoTxHash() throws {
        let operation = try createAssetHubOperation(submitMonitor: createRejectingSubmitMonitor())

        let failure = try performFailingHop(operation.executeWrapper(for: Self.swapLimit))

        XCTAssertEqual(failure.stage, .notSubmitted)
        XCTAssertEqual(failure.error as? JSONRPCEngineError, .clientCancelled)
    }

    func testCrosschainHopFailedAfterSubmissionReportsSubmittedTxHash() throws {
        let submission = XcmSubmitExtrinsic(submittedModel: createSubmittedModel(), callPath: Self.xcmCallPath)

        let failure = try performFailingCrosschainHop(submitResult: .success(submission))

        XCTAssertEqual(failure.stage, .submitted(txHash: Self.txHash))
        XCTAssertTrue(failure.error is XcmDepositMonitoringServiceError)
    }

    func testCrosschainHopFailedBeforeSubmissionReportsNoTxHash() throws {
        let failure = try performFailingCrosschainHop(submitResult: .failure(JSONRPCEngineError.clientCancelled))

        XCTAssertEqual(failure.stage, .notSubmitted)
        XCTAssertEqual(failure.error as? JSONRPCEngineError, .clientCancelled)
    }
}

private extension AssetExchangeOperationFailureTests {
    static let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)
    static let blockHash = Data(repeating: 8, count: 32).toHex(includePrefix: true)
    static let xcmCallPath = CallCodingPath(moduleName: "XcmPallet", callName: "transfer_assets")

    static let swapLimit = AssetExchangeSwapLimit(
        direction: .sell,
        amountIn: 1_000_000,
        amountOut: 990_000,
        slippage: BigRational(numerator: 1, denominator: 100)
    )

    var chain: ChainModel { CommissionTestFixtures.chain }

    var operationArgs: AssetExchangeAtomicOperationArgs {
        AssetExchangeAtomicOperationArgs(
            swapLimit: Self.swapLimit,
            feeAsset: CommissionTestFixtures.asset(0),
            commission: nil
        )
    }

    func createEdge(type: AssetExchangeEdgeType) -> StubAssetExchangeEdge {
        StubAssetExchangeEdge(
            origin: CommissionTestFixtures.asset(0),
            destination: CommissionTestFixtures.asset(1),
            type: type,
            chain: chain
        )
    }

    func createHydraOperation(
        submitMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    ) throws -> HydraExchangeAtomicOperation {
        let paramsFactory = MockHydraExchangeExtrinsicParamsFactoryProtocol()
        stub(paramsFactory) { stub in
            when(stub.createOperationWrapper(for: any(), callArgs: any(), commission: any())).then { _, callArgs, _ in
                .createWithResult(
                    CommissionTestFixtures.makeSwapParams(commission: nil, storageInfo: nil, callArgs: callArgs)
                )
            }
        }

        let account = AccountGenerator.generateSubstrateChainAccountResponse(for: chain.chainId)
        let signer = try DummySigner(cryptoType: .sr25519)
        let runtimeProvider = MockRuntimeProviderProtocol().applyDefault(for: chain.chainId)

        let host = MockHydraExchangeHostProtocol()
        stub(host) { stub in
            when(stub.selectedAccount.get).thenReturn(account)
            when(stub.extrinsicParamsFactory.get).thenReturn(paramsFactory)
            when(stub.submissionMonitorFactory.get).thenReturn(submitMonitor)
            when(stub.signingWrapper.get).thenReturn(signer)
            when(stub.runtimeService.get).thenReturn(runtimeProvider)
            when(stub.operationQueue.get).thenReturn(OperationQueue())
            when(stub.logger.get).thenReturn(Logger.shared)
        }

        return HydraExchangeAtomicOperation(
            host: host,
            operationArgs: operationArgs,
            edges: [createEdge(type: .hydraSwap)]
        )
    }

    func createAssetHubOperation(
        submitMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    ) throws -> AssetHubExchangeAtomicOperation {
        let codingFactory = try RuntimeCodingServiceStub.createWestendCodingFactory()

        let paramsFactory = MockAssetHubExchangeExtrinsicParamsFactoryProtocol()
        stub(paramsFactory) { stub in
            when(stub.createOperationWrapper(callArgs: any(), commission: any())).then { callArgs, _ in
                .createWithResult(Self.createAssetHubParams(callArgs: callArgs, codingFactory: codingFactory))
            }
        }

        let account = AccountGenerator.generateSubstrateChainAccountResponse(for: chain.chainId)
        let signer = try DummySigner(cryptoType: .sr25519)
        let runtimeProvider = MockRuntimeProviderProtocol().applyDefault(for: chain.chainId)

        let host = MockAssetHubExchangeHostProtocol()
        stub(host) { stub in
            when(stub.selectedAccount.get).thenReturn(account)
            when(stub.extrinsicParamsFactory.get).thenReturn(paramsFactory)
            when(stub.submissionMonitorFactory.get).thenReturn(submitMonitor)
            when(stub.signingWrapper.get).thenReturn(signer)
            when(stub.runtimeService.get).thenReturn(runtimeProvider)
            when(stub.operationQueue.get).thenReturn(OperationQueue())
            when(stub.logger.get).thenReturn(Logger.shared)
        }

        return AssetHubExchangeAtomicOperation(
            host: host,
            operationArgs: operationArgs,
            edge: createEdge(type: .assetHubSwap)
        )
    }

    static func createAssetHubParams(
        callArgs: AssetConversion.CallArgs,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> AssetHubExchangeSwapParams {
        AssetHubExchangeSwapParams(
            callArgs: callArgs,
            path: [],
            swap: .exactIn(
                .init(
                    path: [],
                    amountIn: callArgs.amountIn,
                    amountOutMin: callArgs.amountOut,
                    sendTo: callArgs.receiver,
                    keepAlive: false
                )
            ),
            commission: nil,
            codingFactory: codingFactory
        )
    }

    func createSubmittedModel() -> ExtrinsicSubmittedModel {
        let sender = AccountGenerator.generateSubstrateChainAccountResponse(for: chain.chainId)

        return ExtrinsicSubmittedModel(txHash: Self.txHash, sender: .current(sender))
    }

    func createDispatchFailingSubmitMonitor() -> ExtrinsicSubmitMonitorFactoryProtocol {
        let failedExtrinsic = SubstrateExtrinsicStatus.FailedExtrinsic(
            extrinsicHash: Self.txHash,
            blockHash: Self.blockHash,
            error: .other(.init(module: "Router", reason: "TradingLimitReached"))
        )

        let submission = ExtrinsicMonitorSubmission(
            extrinsicSubmittedModel: createSubmittedModel(),
            status: .failure(failedExtrinsic)
        )

        return createSubmitMonitor { .createWithResult(submission) }
    }

    func createRejectingSubmitMonitor() -> ExtrinsicSubmitMonitorFactoryProtocol {
        createSubmitMonitor { .createWithError(JSONRPCEngineError.clientCancelled) }
    }

    func createSubmitMonitor(
        _ wrapperClosure: @escaping () -> CompoundOperationWrapper<ExtrinsicMonitorSubmission>
    ) -> ExtrinsicSubmitMonitorFactoryProtocol {
        let submitMonitor = MockExtrinsicSubmitMonitorFactoryProtocol()
        stub(submitMonitor) { stub in
            when(stub.submitAndMonitorWrapper(
                extrinsicBuilderClosure: any(),
                payingIn: any(),
                signer: any(),
                matchingEvents: any()
            )).then { _, _, _, _ in wrapperClosure() }
        }

        return submitMonitor
    }

    func performFailingCrosschainHop(
        submitResult: XcmSubmitExtrinsicResult
    ) throws -> AssetExchangeOperationFailure {
        let transferService = MockXcmTransferServiceProtocol()
        stub(transferService) { stub in
            when(stub.submit(
                request: any(),
                signer: any(),
                runningIn: any(),
                completion: any()
            )).then { _, _, _, completion in
                completion(submitResult)
            }
        }

        let transactService = XcmTransactService(
            chainRegistry: MockChainRegistryProtocol(),
            transferService: transferService,
            workingQueue: .global(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let destination = createAssetWithoutArrivalDetection()

        let wrapper = try transactService.transferAndWaitArrivalWrapper(
            createTransferRequest(to: destination),
            destinationChainAsset: destination,
            signer: DummySigner(cryptoType: .sr25519)
        )

        return try performFailingHop(wrapper)
    }

    func createAssetWithoutArrivalDetection() -> ChainAsset {
        let asset = AssetModel(
            assetId: 0,
            icon: nil,
            name: nil,
            symbol: "GLMR",
            precision: 18,
            priceId: nil,
            stakings: nil,
            type: AssetType.evmNative.rawValue,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(assets: [asset], addressPrefix: 1284)

        return ChainAsset(chain: chain, asset: asset)
    }

    func createTransferRequest(to destination: ChainAsset) -> XcmTransferRequest {
        let origin = CommissionTestFixtures.chainAsset(0)

        let metadata = XcmTransferMetadata(
            callType: .xcmpalletTransferAssets,
            reserve: .init(reserveId: origin.chain.chainId, path: .init(type: .relative, path: .null)),
            fee: .dynamic,
            paysDeliveryFee: false,
            supportsXcmExecute: false,
            usesTeleport: false
        )

        return XcmTransferRequest(
            unweighted: XcmUnweightedTransferRequest(
                origin: XcmTransferOrigin(chainAsset: origin, parachainId: nil),
                destination: XcmTransferDestination(
                    chainAsset: destination,
                    parachainId: nil,
                    accountId: AccountId(repeating: 2, count: 20)
                ),
                reserve: XcmTransferReserve(chain: origin.chain, parachainId: nil),
                metadata: metadata,
                amount: Self.swapLimit.amountIn
            )
        )
    }

    func performFailingHop(_ wrapper: CompoundOperationWrapper<Balance>) throws -> AssetExchangeOperationFailure {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        var failure: AssetExchangeOperationFailure?

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData()) {
            failure = AssetExchangeOperationFailure(wrapping: $0)
        }

        return try XCTUnwrap(failure)
    }
}

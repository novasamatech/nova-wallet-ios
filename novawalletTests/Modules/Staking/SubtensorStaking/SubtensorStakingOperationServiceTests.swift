import BigInt
import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorStakingOperationServiceTests: XCTestCase {
    private let coldkey = Data(repeating: 0x11, count: 32)
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let beneficiary = Data(repeating: 0xBB, count: 32)
    private let netuid: UInt16 = 64
    private let extrinsicHash = "0x" + String(repeating: "07", count: 32)
    private let blockHash = "0x" + String(repeating: "08", count: 32)

    private var sellOperation: SubtensorStakingOperation {
        .subnetSell(
            hotkey: hotkey,
            netuid: netuid,
            alpha: 56_200_000_000,
            limitPrice: 73_431_000,
            quotedTaoOut: 4_145_000_000
        )
    }

    private var slippageError: DispatchCallError {
        DispatchCallError.module(
            .init(
                raw: .init(moduleIndex: 7, error: Data(repeating: 0, count: 4)),
                display: .init(moduleName: "SubtensorModule", errorName: "SlippageTooHigh")
            )
        )
    }

    func testSuccessfulSellReturnsOutcomeThenRefreshesPositionsAndPostsStakingChanged() throws {
        let removedHex = "0703" + coldkey.toHex() + hotkey.toHex() + le(UInt64(4_145_000_000)) +
            le(UInt64(56_171_700_618)) + le(netuid) + le(UInt64(28_299_382))
        let feeTransferHex = "0502" + coldkey.toHex() + beneficiary.toHex() + le(UInt64(34_935_547))
        let networkFeeHex = "0600" + coldkey.toHex() + le(UInt64(1_500_000)) + le(UInt64(0))

        let events = try decodeEvents([removedHex, feeTransferHex, networkFeeHex])
        let context = try makeContext(status: .success(.init(
            extrinsicHash: extrinsicHash,
            blockHash: blockHash,
            interestedEvents: events
        )))

        stubRefreshAndNotify(context)

        let outcome = try run(context.service.createSubmitWrapper(for: sellOperation)).get()

        let expected = SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: 4_145_000_000, alpha: 56_200_000_000, netuid: netuid),
            novaFeePaid: 34_935_547,
            alphaFeePaid: nil,
            networkFeePaid: 1_500_000,
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        )

        let eventCaptor = ArgumentCaptor<EventProtocol>()

        XCTAssertEqual(outcome, expected)
        XCTAssertEqual(context.sharedOperation.status, .sent)
        verify(context.positionsSyncService, times(1)).refresh()
        verify(context.eventCenter, times(1)).notify(with: eventCaptor.capture())

        let changed = try XCTUnwrap(eventCaptor.value as? SubtensorStakingChanged)

        XCTAssertEqual(changed.chainAssetId, context.chainAsset.chainAssetId)
        XCTAssertEqual(changed.accountId, coldkey)
    }

    func testDispatchFailureReportsDispatchedStageAndRestoresTheCapturedStatusWithoutRefresh() throws {
        let context = try makeContext(status: .failure(.init(
            extrinsicHash: extrinsicHash,
            blockHash: blockHash,
            error: slippageError
        )))

        stubRefreshAndNotify(context)

        context.sharedOperation.markSent()

        let failure = try submissionFailure(of: context.service.createSubmitWrapper(for: sellOperation))

        XCTAssertEqual(failure.stage, .dispatched(blockHash: blockHash, extrinsicHash: extrinsicHash))
        XCTAssertEqual(failure.error as? SubtensorStakingSubmissionError, .slippageTooHigh)
        XCTAssertEqual(context.sharedOperation.status, .sent)
        verify(context.positionsSyncService, never()).refresh()
        verify(context.eventCenter, never()).notify(with: any())
    }

    func testSigningCancelledFailsAsNotSubmittedAndReopensComposing() throws {
        let submitMonitor = makeFailingSubmitMonitor(signingFirst: false, error: HardwareSigningError.signingCancelled)
        let context = try makeContext(
            status: .failure(.init(extrinsicHash: extrinsicHash, blockHash: blockHash, error: slippageError)),
            submitMonitor: submitMonitor
        )

        stubRefreshAndNotify(context)

        let failure = try submissionFailure(of: context.service.createSubmitWrapper(for: sellOperation))

        XCTAssertEqual(failure.stage, .notSubmitted)
        XCTAssertEqual(failure.error as? HardwareSigningError, .signingCancelled)
        XCTAssertEqual(context.sharedOperation.status, .composing)
        verify(context.positionsSyncService, never()).refresh()
        verify(context.eventCenter, never()).notify(with: any())
    }

    func testErrorAfterSignatureIsUnconfirmedKeepsSentRefreshesAndPostsStakingChanged() throws {
        let submitMonitor = makeFailingSubmitMonitor(signingFirst: true, error: JSONRPCEngineError.clientCancelled)
        let context = try makeContext(
            status: .failure(.init(extrinsicHash: extrinsicHash, blockHash: blockHash, error: slippageError)),
            submitMonitor: submitMonitor
        )

        stubRefreshAndNotify(context)

        let failure = try submissionFailure(of: context.service.createSubmitWrapper(for: sellOperation))

        XCTAssertEqual(failure.stage, .unconfirmed(extrinsicHash: nil))
        XCTAssertEqual(context.sharedOperation.status, .sent)
        verify(context.positionsSyncService, times(1)).refresh()
        verify(context.eventCenter, times(1)).notify(with: any())
    }

    func testPoolFeeRejectionAfterSignatureIsNotSubmittedAndReopensComposing() throws {
        let poolRejection = try JSONDecoder().decode(
            JSONRPCError.self,
            from: Data("{\"code\": 1010, \"message\": \"Invalid Transaction\", \"data\": \"Inability to pay some fees\"}".utf8)
        )

        let submitMonitor = makeFailingSubmitMonitor(signingFirst: true, error: poolRejection)
        let context = try makeContext(
            status: .failure(.init(extrinsicHash: extrinsicHash, blockHash: blockHash, error: slippageError)),
            submitMonitor: submitMonitor
        )

        stubRefreshAndNotify(context)

        let failure = try submissionFailure(of: context.service.createSubmitWrapper(for: sellOperation))

        XCTAssertEqual(failure.stage, .notSubmitted)
        XCTAssertEqual(failure.error as? SubtensorStakingSubmissionError, .feeUnpayable)
        XCTAssertEqual(context.sharedOperation.status, .composing)
        verify(context.positionsSyncService, never()).refresh()
        verify(context.eventCenter, never()).notify(with: any())
    }

    func testCancelBeforeStartFailsAsNotSubmittedWithoutSubmitting() throws {
        let submitMonitor = makeFailingSubmitMonitor(signingFirst: true, error: JSONRPCEngineError.clientCancelled)
        let context = try makeContext(
            status: .failure(.init(extrinsicHash: extrinsicHash, blockHash: blockHash, error: slippageError)),
            submitMonitor: submitMonitor
        )

        stubRefreshAndNotify(context)

        let wrapper = context.service.createSubmitWrapper(for: sellOperation)
        let operationQueue = OperationQueue()

        operationQueue.isSuspended = true

        let completed = enqueue(wrapper, in: operationQueue)

        wrapper.cancel()
        operationQueue.isSuspended = false

        wait(for: [completed], timeout: 10)

        let failure = try finishedSubmissionFailure(of: wrapper)

        XCTAssertEqual(failure.stage, .notSubmitted)
        XCTAssertEqual(context.sharedOperation.status, .composing)
        verify(submitMonitor, never()).submitAndMonitorWrapper(
            extrinsicBuilderClosure: any(),
            payingIn: any(),
            signer: any(),
            matchingEvents: any()
        )
        verify(context.positionsSyncService, never()).refresh()
    }

    func testSubmissionCancelledInFlightStaysSentThenReportsItsDispatchFailureAndReopens() throws {
        let submissionStarted = expectation(description: "submission started")
        var completeSubmission: ((Result<ExtrinsicMonitorSubmission, Error>) -> Void)?
        let submitMonitor = MockExtrinsicSubmitMonitorFactoryProtocol()

        stub(submitMonitor) { stub in
            when(stub.submitAndMonitorWrapper(
                extrinsicBuilderClosure: any(),
                payingIn: any(),
                signer: any(),
                matchingEvents: any()
            )).then { _, _, _, _ in
                CompoundOperationWrapper(targetOperation: AsyncClosureOperation<ExtrinsicMonitorSubmission> { completion in
                    completeSubmission = completion
                    submissionStarted.fulfill()
                })
            }
        }

        let context = try makeContext(
            status: .failure(.init(extrinsicHash: extrinsicHash, blockHash: blockHash, error: slippageError)),
            submitMonitor: submitMonitor
        )

        stubRefreshAndNotify(context)

        let wrapper = context.service.createSubmitWrapper(for: sellOperation)
        let completed = enqueue(wrapper)

        wait(for: [submissionStarted], timeout: 10)

        wrapper.cancel()
        drainMainQueue()

        XCTAssertEqual(context.sharedOperation.status, .sent)

        completeSubmission?(.success(ExtrinsicMonitorSubmission(
            extrinsicSubmittedModel: ExtrinsicSubmittedModel(
                txHash: extrinsicHash,
                sender: .current(AccountGenerator.generateSubstrateChainAccountResponse(for: KnowChainId.bittensor))
            ),
            status: .failure(.init(extrinsicHash: extrinsicHash, blockHash: blockHash, error: slippageError))
        )))

        wait(for: [completed], timeout: 10)

        let failure = try finishedSubmissionFailure(of: wrapper)

        XCTAssertEqual(failure.stage, .dispatched(blockHash: blockHash, extrinsicHash: extrinsicHash))
        XCTAssertEqual(context.sharedOperation.status, .composing)
        verify(submitMonitor, times(1)).submitAndMonitorWrapper(
            extrinsicBuilderClosure: any(),
            payingIn: any(),
            signer: any(),
            matchingEvents: any()
        )
        verify(context.positionsSyncService, never()).refresh()
    }

    func testSubnetSellWithoutBeneficiaryFailsAsNotSubmittedWithoutSubmitting() throws {
        let submitMonitor = MockExtrinsicSubmitMonitorFactoryProtocol()
        let context = try makeContext(
            status: .success(.init(extrinsicHash: extrinsicHash, blockHash: blockHash, interestedEvents: [])),
            beneficiary: nil,
            submitMonitor: submitMonitor
        )

        stubRefreshAndNotify(context)

        let failure = try submissionFailure(of: context.service.createSubmitWrapper(for: sellOperation))

        XCTAssertEqual(failure.stage, .notSubmitted)
        XCTAssertEqual(failure.error as? SubtensorStakingOperationError, .novaFeeUnavailable)
        XCTAssertEqual(context.sharedOperation.status, .composing)
        verify(submitMonitor, never()).submitAndMonitorWrapper(
            extrinsicBuilderClosure: any(),
            payingIn: any(),
            signer: any(),
            matchingEvents: any()
        )
        verify(context.positionsSyncService, never()).refresh()
    }

    func testFeeWrapperReturnsTheEstimatedNetworkFee() throws {
        let context = try makeContext(
            status: .success(.init(extrinsicHash: extrinsicHash, blockHash: blockHash, interestedEvents: []))
        )

        let fee = try run(context.service.createFeeWrapper(for: sellOperation)).get()

        XCTAssertEqual(fee.amount, 734_304)
    }

    private struct Context {
        let chainAsset: ChainAsset
        let service: SubtensorStakingOperationService
        let positionsSyncService: MockSubtensorPositionsSyncServiceProtocol
        let eventCenter: MockEventCenterProtocol
        let sharedOperation: SharedOperation
    }

    private func makeContext(
        status: SubstrateExtrinsicStatus,
        beneficiary: AccountId? = Data(repeating: 0xBB, count: 32),
        submitMonitor: ExtrinsicSubmitMonitorFactoryProtocol? = nil
    ) throws -> Context {
        let chainAsset = makeChainAsset()
        let positionsSyncService = MockSubtensorPositionsSyncServiceProtocol()
        let eventCenter = MockEventCenterProtocol()
        let sharedOperation = SharedOperation()

        let chainAccount = AccountGenerator.generateSubstrateChainAccountResponse(for: KnowChainId.bittensor)
        let submission = ExtrinsicMonitorSubmission(
            extrinsicSubmittedModel: ExtrinsicSubmittedModel(txHash: extrinsicHash, sender: .current(chainAccount)),
            status: status
        )

        let networkFee = ExtrinsicFee(amount: 734_304, payer: nil, weight: .zero)

        let service = try SubtensorStakingOperationService(
            chainAsset: chainAsset,
            accountId: coldkey,
            extrinsicService: ExtrinsicServiceStub(
                feeResult: .success(networkFee),
                submittedModelResult: .success(submission.extrinsicSubmittedModel)
            ),
            extrinsicSubmitMonitor: submitMonitor ?? ExtrinsicSubmitMonitorFactoryStub(submission: submission),
            signer: DummySigner(cryptoType: .sr25519),
            runtimeProvider: RuntimeCodingServiceStub(factory: RuntimeCodingServiceStub.createBittensorCodingFactory()),
            positionsSyncService: positionsSyncService,
            sharedOperation: sharedOperation,
            eventCenter: eventCenter,
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: beneficiary),
            operationQueue: OperationQueue()
        )

        return Context(
            chainAsset: chainAsset,
            service: service,
            positionsSyncService: positionsSyncService,
            eventCenter: eventCenter,
            sharedOperation: sharedOperation
        )
    }

    private func makeFailingSubmitMonitor(
        signingFirst: Bool,
        error: Error
    ) -> MockExtrinsicSubmitMonitorFactoryProtocol {
        let submitMonitor = MockExtrinsicSubmitMonitorFactoryProtocol()

        stub(submitMonitor) { stub in
            when(stub.submitAndMonitorWrapper(
                extrinsicBuilderClosure: any(),
                payingIn: any(),
                signer: any(),
                matchingEvents: any()
            )).then { _, _, signer, _ in
                CompoundOperationWrapper(targetOperation: ClosureOperation<ExtrinsicMonitorSubmission> {
                    if signingFirst {
                        _ = try signer.sign(Data(repeating: 1, count: 32), context: .rawBytes)
                    }

                    throw error
                })
            }
        }

        return submitMonitor
    }

    private func stubRefreshAndNotify(_ context: Context) {
        stub(context.positionsSyncService) { stub in
            when(stub.refresh()).thenDoNothing()
        }

        stub(context.eventCenter) { stub in
            when(stub.notify(with: any())).thenDoNothing()
        }
    }

    private func makeChainAsset() -> ChainAsset {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: [.subtensor],
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func decodeEvents(_ eventsHex: [String]) throws -> [Event] {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()
        let entry = try XCTUnwrap(codingFactory.metadata.getStorageMetadata(for: SystemPallet.eventsPath))

        let recordsHex = le(UInt8(eventsHex.count << 2)) + eventsHex.map { "00" + "00000000" + $0 + "00" }.joined()
        let decoder = try codingFactory.createDecoder(from: Data(hexString: recordsHex))
        let json = try decoder.read(type: entry.type.typeName)

        return try json.map(
            to: [EventRecord].self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        ).map(\.event)
    }

    private func le<T: FixedWidthInteger>(_ value: T) -> String {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }.toHex()
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")

        DispatchQueue.main.async {
            drained.fulfill()
        }

        wait(for: [drained], timeout: 10)
    }

    private func submissionFailure<T>(
        of wrapper: CompoundOperationWrapper<T>
    ) throws -> SubtensorStakingSubmissionFailure {
        wait(for: [enqueue(wrapper)], timeout: 10)

        return try finishedSubmissionFailure(of: wrapper)
    }

    private func finishedSubmissionFailure<T>(
        of wrapper: CompoundOperationWrapper<T>
    ) throws -> SubtensorStakingSubmissionFailure {
        drainMainQueue()

        var failure: SubtensorStakingSubmissionFailure?

        if case let .failure(error)? = wrapper.targetOperation.result {
            failure = error as? SubtensorStakingSubmissionFailure
        }

        return try XCTUnwrap(failure)
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) -> Result<T, Error> {
        wait(for: [enqueue(wrapper)], timeout: 10)

        return Result { try wrapper.targetOperation.extractNoCancellableResultData() }
    }

    private func enqueue<T>(
        _ wrapper: CompoundOperationWrapper<T>,
        in operationQueue: OperationQueue = OperationQueue()
    ) -> XCTestExpectation {
        let completed = expectation(description: "wrapper completed")

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                completed.fulfill()
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

        return completed
    }
}

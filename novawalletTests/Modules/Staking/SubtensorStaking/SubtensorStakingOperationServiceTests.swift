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
    private let extrinsicHash = "0x" + String(repeating: "07", count: 32)
    private let blockHash = "0x" + String(repeating: "08", count: 32)

    func testSuccessfulSellReturnsOutcomeRefreshesPositionsAndPostsStakingChanged() throws {
        let events = try SubtensorFixtureDecoding.decodeEvents(
            [
                SubtensorFixtureDecoding.stakeRemovedEvent(
                    coldkey: coldkey,
                    hotkey: hotkey,
                    netuid: 64,
                    tao: 4_145_000_000,
                    alpha: 56_171_700_618,
                    poolFee: 28_299_382
                ),
                SubtensorFixtureDecoding.transferEvent(from: coldkey, to: beneficiary, amount: 34_935_547),
                SubtensorFixtureDecoding.transactionFeePaidEvent(who: coldkey, actualFee: 1_500_000)
            ],
            codingFactory: RuntimeCodingServiceStub.createBittensorCodingFactory()
        )
        let status = SubstrateExtrinsicStatus.success(
            .init(extrinsicHash: extrinsicHash, blockHash: blockHash, interestedEvents: events)
        )
        let context = try setupContext(submitMonitor: createSubmitMonitor(status: status))

        let outcome = try performSubmit(with: context).get()

        XCTAssertEqual(outcome, SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: 4_145_000_000, alpha: 56_200_000_000, netuid: 64),
            novaFeePaid: 34_935_547,
            alphaFeePaid: nil,
            networkFeePaid: 1_500_000,
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        ))
        XCTAssertEqual(context.sharedOperation.status, .sent)
        verify(context.positionsSyncService, times(1)).refresh()
        let eventCaptor = ArgumentCaptor<EventProtocol>()
        verify(context.eventCenter, times(1)).notify(with: eventCaptor.capture())
        let changed = try XCTUnwrap(eventCaptor.value as? SubtensorStakingChanged)
        XCTAssertEqual(changed.chainAssetId, context.service.chainAsset.chainAssetId)
        XCTAssertEqual(changed.accountId, coldkey)
    }

    func testDispatchFailureReportsDispatchedStageWithoutRefresh() throws {
        let slippageError = DispatchCallError.module(
            .init(
                raw: .init(moduleIndex: 7, error: Data(repeating: 0, count: 4)),
                display: .init(moduleName: "SubtensorModule", errorName: "SlippageTooHigh")
            )
        )
        let status = SubstrateExtrinsicStatus.failure(
            .init(extrinsicHash: extrinsicHash, blockHash: blockHash, error: slippageError)
        )
        let context = try setupContext(submitMonitor: createSubmitMonitor(status: status))

        let failure = try performFailingSubmit(with: context)

        XCTAssertEqual(failure.stage, .dispatched(blockHash: blockHash, extrinsicHash: extrinsicHash))
        XCTAssertEqual(failure.error as? SubtensorStakingSubmissionError, .slippageTooHigh)
        XCTAssertEqual(context.sharedOperation.status, .composing)
        verify(context.positionsSyncService, never()).refresh()
        verify(context.eventCenter, never()).notify(with: any())
    }

    func testErrorAfterSignatureIsUnconfirmedAndRefreshes() throws {
        let submitMonitor = MockExtrinsicSubmitMonitorFactoryProtocol()
        stub(submitMonitor) { stub in
            when(stub.submitAndMonitorWrapper(
                extrinsicBuilderClosure: any(),
                payingIn: any(),
                signer: any(),
                matchingEvents: any()
            )).then { _, _, signer, _ in
                CompoundOperationWrapper(targetOperation: ClosureOperation<ExtrinsicMonitorSubmission> {
                    _ = try signer.sign(Data(repeating: 1, count: 32), context: .rawBytes)
                    throw JSONRPCEngineError.clientCancelled
                })
            }
        }
        let context = try setupContext(submitMonitor: submitMonitor)

        let failure = try performFailingSubmit(with: context)

        XCTAssertEqual(failure.stage, .unconfirmed(extrinsicHash: nil))
        XCTAssertEqual(context.sharedOperation.status, .sent)
        verify(context.positionsSyncService, times(1)).refresh()
        verify(context.eventCenter, times(1)).notify(with: any())
    }

    func testSellWithoutBeneficiaryFailsAsNotSubmittedWithoutSubmitting() throws {
        let submitMonitor = MockExtrinsicSubmitMonitorFactoryProtocol()
        let context = try setupContext(submitMonitor: submitMonitor, beneficiary: nil)

        let failure = try performFailingSubmit(with: context)

        XCTAssertEqual(failure.stage, .notSubmitted)
        XCTAssertEqual(failure.error as? SubtensorStakingOperationError, .novaFeeUnavailable)
        XCTAssertEqual(context.sharedOperation.status, .composing)
        verify(submitMonitor, never()).submitAndMonitorWrapper(
            extrinsicBuilderClosure: any(),
            payingIn: any(),
            signer: any(),
            matchingEvents: any()
        )
    }

    private struct Context {
        let service: SubtensorStakingOperationService
        let positionsSyncService: MockSubtensorPositionsSyncServiceProtocol
        let eventCenter: MockEventCenterProtocol
        let sharedOperation: SharedOperation
    }

    private func setupContext(
        submitMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        beneficiary: AccountId? = Data(repeating: 0xBB, count: 32)
    ) throws -> Context {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)
        let chainAsset = try XCTUnwrap(chain.utilityChainAsset())
        let positionsSyncService = MockSubtensorPositionsSyncServiceProtocol()
        stub(positionsSyncService) { stub in
            when(stub.refresh()).thenDoNothing()
        }
        let eventCenter = MockEventCenterProtocol().applyingDefaultStub()
        let sharedOperation = SharedOperation()

        let service = try SubtensorStakingOperationService(
            chainAsset: chainAsset,
            accountId: coldkey,
            extrinsicService: ExtrinsicServiceStub.dummy(),
            extrinsicSubmitMonitor: submitMonitor,
            signer: DummySigner(cryptoType: .sr25519),
            runtimeProvider: RuntimeCodingServiceStub(factory: RuntimeCodingServiceStub.createBittensorCodingFactory()),
            positionsSyncService: positionsSyncService,
            sharedOperation: sharedOperation,
            eventCenter: eventCenter,
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: beneficiary),
            operationQueue: OperationQueue()
        )

        return Context(
            service: service,
            positionsSyncService: positionsSyncService,
            eventCenter: eventCenter,
            sharedOperation: sharedOperation
        )
    }

    private func createSubmitMonitor(status: SubstrateExtrinsicStatus) -> ExtrinsicSubmitMonitorFactoryProtocol {
        let sender = AccountGenerator.generateSubstrateChainAccountResponse(for: KnowChainId.bittensor)
        let submission = ExtrinsicMonitorSubmission(
            extrinsicSubmittedModel: ExtrinsicSubmittedModel(txHash: extrinsicHash, sender: .current(sender)),
            status: status
        )

        return ExtrinsicSubmitMonitorFactoryStub(submission: submission)
    }

    private func performSubmit(with context: Context) -> Result<SubtensorStakingOperationOutcome, Error> {
        let operation = SubtensorStakingOperation.subnetSell(
            hotkey: hotkey,
            netuid: 64,
            alpha: 56_200_000_000,
            limitPrice: 73_431_000,
            quotedTaoOut: 4_145_000_000
        )
        let wrapper = context.service.createSubmitWrapper(for: operation) {}
        let completed = expectation(description: "submission completed")
        wrapper.targetOperation.completionBlock = { DispatchQueue.main.async { completed.fulfill() } }

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: 10)

        return wrapper.targetOperation.result ?? .failure(BaseOperationError.parentOperationCancelled)
    }

    private func performFailingSubmit(with context: Context) throws -> SubtensorStakingSubmissionFailure {
        var failure: SubtensorStakingSubmissionFailure?

        if case let .failure(error) = performSubmit(with: context) {
            failure = error as? SubtensorStakingSubmissionFailure
        }

        return try XCTUnwrap(failure)
    }
}

import BigInt
import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorSubmissionOperationFactoryTests: XCTestCase {
    private let coldkey = Data(repeating: 0x11, count: 32)
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let beneficiary = Data(repeating: 0xBB, count: 32)
    private let extrinsicHash = "0x" + String(repeating: "07", count: 32)
    private let blockHash = "0x" + String(repeating: "08", count: 32)
    private let blockTime: BlockTime = 1

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

        XCTAssertEqual(outcome, SubtensorOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: 4_145_000_000, alpha: 56_200_000_000, netuid: 64),
            novaFeePaid: 34_935_547,
            alphaFeePaid: nil,
            networkFeePaid: 1_500_000,
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        ))
        XCTAssertEqual(context.sharedOperation.status, .sent)
        let eventCaptor = ArgumentCaptor<EventProtocol>()
        verify(context.eventCenter, times(1)).notify(with: eventCaptor.capture())
        let changed = try XCTUnwrap(eventCaptor.value as? SubtensorStakeChanged)
        XCTAssertEqual(changed.chainAssetId, context.operationFactory.chainAsset.chainAssetId)
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
        XCTAssertEqual(failure.error as? SubtensorSubmissionError, .slippageTooHigh)
        XCTAssertEqual(context.sharedOperation.status, .composing)
        verify(context.eventCenter, never()).notify(with: any())
    }

    func testErrorAfterSignatureIsUnconfirmedAndRefreshes() throws {
        let context = try setupContext(submitMonitor: createSigningThenFailingSubmitMonitor())

        let failure = try performFailingSubmit(with: context)

        XCTAssertEqual(failure.stage, .unconfirmed(extrinsicHash: nil))
        XCTAssertEqual(context.sharedOperation.status, .sent)
        verify(context.eventCenter, times(1)).notify(with: any())
    }

    func testSellWithoutBeneficiaryFailsAsNotSubmittedWithoutSubmitting() throws {
        let submitMonitor = MockExtrinsicSubmitMonitorFactoryProtocol()
        let context = try setupContext(submitMonitor: submitMonitor, beneficiary: nil)

        let failure = try performFailingSubmit(with: context)

        XCTAssertEqual(failure.stage, .notSubmitted)
        XCTAssertEqual(failure.error as? SubtensorOperationError, .novaFeeUnavailable)
        XCTAssertEqual(context.sharedOperation.status, .composing)
        verify(submitMonitor, never()).submitAndMonitorWrapper(
            extrinsicBuilderClosure: any(),
            payingIn: any(),
            signer: any(),
            matchingEvents: any()
        )
    }

    func testShieldedSellWithoutNextKeyFailsAsNotExecutedWithoutClearSigning() throws {
        let nextKeyFactory = MockMevShieldOperationFactoryProtocol()
        stub(nextKeyFactory) { stub in
            when(stub.createNextKeyWrapper()).then { .createWithResult(nil) }
        }
        let context = try setupContext(
            submitMonitor: createSigningThenFailingSubmitMonitor(),
            nextKeyFactory: nextKeyFactory
        )
        var signedRoutes: [SubtensorSubmissionRoute] = []

        let failure = try performFailingSubmit(with: context, shielded: true) { signedRoutes.append($0) }

        XCTAssertEqual(failure.stage, .notSubmitted)
        XCTAssertEqual(failure.error as? SubtensorSubmissionError, .shieldedNotExecuted)
        XCTAssertEqual(signedRoutes, [])
        verify(nextKeyFactory, times(3)).createNextKeyWrapper()
    }

    private struct Context {
        let operationFactory: SubtensorSubmissionOperationFactory
        let eventCenter: MockEventCenterProtocol
        let sharedOperation: SharedOperation
    }

    private func setupContext(
        submitMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        beneficiary: AccountId? = Data(repeating: 0xBB, count: 32),
        nextKeyFactory: MevShieldOperationFactoryProtocol? = nil
    ) throws -> Context {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)
        let chainAsset = try XCTUnwrap(chain.utilityChainAsset())
        let eventCenter = MockEventCenterProtocol().applyingDefaultStub()
        let sharedOperation = SharedOperation()

        let operationFactory = try SubtensorSubmissionOperationFactory(
            chainAsset: chainAsset,
            accountId: coldkey,
            extrinsicService: ExtrinsicServiceStub.dummy(),
            extrinsicSubmitMonitor: submitMonitor,
            signer: DummySigner(cryptoType: .sr25519),
            runtimeProvider: RuntimeCodingServiceStub(factory: RuntimeCodingServiceStub.createBittensorCodingFactory()),
            sharedOperation: sharedOperation,
            eventCenter: eventCenter,
            configProvider: MockSubtensorConfigProviding(),
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: beneficiary),
            shield: nextKeyFactory.map { createShield(on: chain, nextKeyFactory: $0) }
        )

        return Context(
            operationFactory: operationFactory,
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

    private func createSigningThenFailingSubmitMonitor() -> ExtrinsicSubmitMonitorFactoryProtocol {
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

        return submitMonitor
    }

    private func createShield(
        on chain: ChainModel,
        nextKeyFactory: MevShieldOperationFactoryProtocol
    ) -> SubtensorShieldServices {
        let connection = TestJSONRPCEngine()
        let runtimeProvider = MockRuntimeProviderProtocol()
        let operationQueue = OperationQueue()
        let statusService = ExtrinsicStatusService(
            connection: connection,
            runtimeProvider: runtimeProvider,
            eventsQueryFactory: BlockEventsQueryFactory(operationQueue: operationQueue),
            logger: Logger.shared
        )
        let fundsFactory = MockSubtensorShieldFundsFactoryProtocol()
        stub(fundsFactory) { stub in
            when(stub.createFundsWrapper()).then {
                .createWithResult(SubtensorShieldFunds(transferable: 1_000_000_000_000, existentialDeposit: 500))
            }
        }

        let extrinsicFactory = SubtensorShieldExtrinsicFactory(
            account: AccountGenerator.generateSubstrateChainAccountResponse(for: chain.chainId),
            chain: chain,
            connection: connection,
            extrinsicServiceFactory: ExtrinsicServiceFactoryStub(),
            keyOperationFactory: nextKeyFactory,
            sealer: MevShieldSealer(),
            operationQueue: operationQueue,
            nonceOperationFactory: PresetNonceOperationFactory(nonce: 0)
        )

        let submissionFactory = SubtensorShieldSubmissionFactory(
            walletType: .secrets,
            extrinsicFactory: extrinsicFactory,
            fundsFactory: fundsFactory,
            carrierWatch: SubtensorShieldCarrierWatch(connection: connection),
            inclusionTracker: SubtensorShieldInclusionTracker(
                connection: connection,
                statusService: statusService,
                operationQueue: operationQueue
            ),
            signerFactory: { try? DummySigner(cryptoType: .sr25519) },
            operationQueue: operationQueue
        )

        return SubtensorShieldServices(submissionFactory: submissionFactory, operationQueue: operationQueue)
    }

    private func performSubmit(
        with context: Context,
        shielded: Bool = false,
        signedClosure: @escaping (SubtensorSubmissionRoute) -> Void = { _ in }
    ) -> Result<SubtensorOperationOutcome, Error> {
        let operation = SubtensorOperation.subnetSell(
            hotkey: hotkey,
            netuid: 64,
            alpha: 56_200_000_000,
            limitPrice: 73_431_000,
            quotedTaoOut: 4_145_000_000,
            novaFee: SubtensorNovaFee(amount: 12_397_806, beneficiary: Data(repeating: 0xBB, count: 32))
        )
        let wrapper = context.operationFactory.createSubmitWrapper(
            for: operation,
            shielded: shielded,
            blockTime: blockTime,
            signedClosure: signedClosure
        )
        let completed = expectation(description: "submission completed")
        wrapper.targetOperation.completionBlock = { DispatchQueue.main.async { completed.fulfill() } }

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: 10)

        return wrapper.targetOperation.result ?? .failure(BaseOperationError.parentOperationCancelled)
    }

    private func performFailingSubmit(
        with context: Context,
        shielded: Bool = false,
        signedClosure: @escaping (SubtensorSubmissionRoute) -> Void = { _ in }
    ) throws -> SubtensorSubmissionFailure {
        var failure: SubtensorSubmissionFailure?

        if case let .failure(error) = performSubmit(with: context, shielded: shielded, signedClosure: signedClosure) {
            failure = error as? SubtensorSubmissionFailure
        }

        return try XCTUnwrap(failure)
    }
}

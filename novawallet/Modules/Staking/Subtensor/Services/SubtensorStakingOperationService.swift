import Foundation
import NovaCrypto
import Operation_iOS
import SubstrateSdk

final class SubtensorStakingOperationService {
    let chainAsset: ChainAsset
    let accountId: AccountId
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    let signer: SigningWrapperProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol?
    let sharedOperation: SharedOperationProtocol?
    let eventCenter: EventCenterProtocol
    let errorMapper: SubtensorStakingErrorMapping
    let feeCalculator: SubtensorNovaFeeCalculator
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue

    init(
        chainAsset: ChainAsset,
        accountId: AccountId,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signer: SigningWrapperProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol?,
        sharedOperation: SharedOperationProtocol?,
        eventCenter: EventCenterProtocol,
        errorMapper: SubtensorStakingErrorMapping = SubtensorStakingErrorMapper(),
        feeCalculator: SubtensorNovaFeeCalculator = SubtensorNovaFeeCalculator(),
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue,
        workingQueue: DispatchQueue = .global(qos: .userInitiated)
    ) {
        self.chainAsset = chainAsset
        self.accountId = accountId
        self.extrinsicService = extrinsicService
        self.extrinsicSubmitMonitor = extrinsicSubmitMonitor
        self.signer = signer
        self.runtimeProvider = runtimeProvider
        self.positionsSyncService = positionsSyncService
        self.sharedOperation = sharedOperation
        self.eventCenter = eventCenter
        self.errorMapper = errorMapper
        self.feeCalculator = feeCalculator
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }
}

private extension SubtensorStakingOperationService {
    func createFinalizer(signer: SubtensorRecordingSigner) -> SubtensorStakingSubmissionFinalizer {
        SubtensorStakingSubmissionFinalizer(
            chainAssetId: chainAsset.chainAssetId,
            accountId: accountId,
            novaFeeBeneficiary: feeCalculator.beneficiary,
            signer: signer,
            positionsSyncService: positionsSyncService,
            eventCenter: eventCenter,
            errorMapper: errorMapper
        )
    }

    func createSubmissionWrapper(
        for operation: SubtensorStakingOperation,
        builderClosure: @escaping ExtrinsicBuilderClosure,
        signer: SubtensorRecordingSigner,
        finalizer: SubtensorStakingSubmissionFinalizer
    ) -> CompoundOperationWrapper<SubtensorStakingOperationOutcome> {
        let submitWrapper = extrinsicSubmitMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: builderClosure,
            payingIn: nil,
            signer: signer,
            matchingEvents: SubtensorStakingEventMatcher()
        )

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let outcomeOperation = ClosureOperation<SubtensorStakingOperationOutcome> {
            let submission: ExtrinsicMonitorSubmission

            do {
                submission = try submitWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                throw finalizer.failure(for: error)
            }

            switch submission.status {
            case let .success(success):
                let codingFactory = try? codingFactoryOperation.extractNoCancellableResultData()

                return try finalizer.complete(operation: operation, success: success, codingFactory: codingFactory)
            case let .failure(failure):
                throw finalizer.dispatchFailure(for: failure)
            }
        }

        outcomeOperation.addDependency(submitWrapper.targetOperation)
        outcomeOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: outcomeOperation,
            dependencies: submitWrapper.allOperations + [codingFactoryOperation]
        )
    }
}

extension SubtensorStakingOperationService: SubtensorStakingOperationServiceProtocol {
    func createFeeWrapper(
        for operation: SubtensorStakingOperation
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        let builderClosure: ExtrinsicBuilderClosure

        do {
            builderClosure = try operation.extrinsicBuilderClosure(feeCalculator: feeCalculator)
        } catch {
            return .createWithError(error)
        }

        let feeOperation = AsyncClosureOperation<ExtrinsicFeeProtocol> { [extrinsicService, workingQueue] completion in
            extrinsicService.estimateFee(builderClosure, runningIn: workingQueue) { result in
                completion(result)
            }
        }

        return CompoundOperationWrapper(targetOperation: feeOperation)
    }

    func createSubmitWrapper(
        for operation: SubtensorStakingOperation
    ) -> CompoundOperationWrapper<SubtensorStakingOperationOutcome> {
        let builderClosure: ExtrinsicBuilderClosure

        do {
            builderClosure = try operation.extrinsicBuilderClosure(feeCalculator: feeCalculator)
        } catch {
            return .createWithError(SubtensorStakingSubmissionFailure(stage: .notSubmitted, error: error))
        }

        let recordingSigner = SubtensorRecordingSigner(signer: signer)
        let finalizer = createFinalizer(signer: recordingSigner)

        let submission = SubtensorStakingSubmission(
            statusKeeper: SubtensorSharedOperationStatusKeeper(sharedOperation: sharedOperation),
            finalizer: finalizer,
            operationQueue: operationQueue
        ) { [self] in
            createSubmissionWrapper(
                for: operation,
                builderClosure: builderClosure,
                signer: recordingSigner,
                finalizer: finalizer
            )
        }

        let submitOperation = SubtensorStakingSubmitOperation(longrun: AnyLongrun(longrun: submission))

        return CompoundOperationWrapper(targetOperation: submitOperation)
    }
}

private final class SubtensorStakingSubmitOperation: LongrunOperation<SubtensorStakingOperationOutcome> {
    override func cancel() {
        longrun.cancel()
    }
}

private final class SubtensorStakingSubmission: Longrunable {
    typealias ResultType = SubtensorStakingOperationOutcome

    private let statusKeeper: SubtensorSharedOperationStatusKeeper
    private let finalizer: SubtensorStakingSubmissionFinalizer
    private let operationQueue: OperationQueue
    private let submissionWrapperClosure: () -> CompoundOperationWrapper<ResultType>
    private let mutex = NSLock()

    private var isCancelled = false

    init(
        statusKeeper: SubtensorSharedOperationStatusKeeper,
        finalizer: SubtensorStakingSubmissionFinalizer,
        operationQueue: OperationQueue,
        submissionWrapperClosure: @escaping () -> CompoundOperationWrapper<ResultType>
    ) {
        self.statusKeeper = statusKeeper
        self.finalizer = finalizer
        self.operationQueue = operationQueue
        self.submissionWrapperClosure = submissionWrapperClosure
    }

    func start(with completionClosure: @escaping (Result<ResultType, Error>) -> Void) {
        mutex.lock()
        let wasCancelled = isCancelled
        mutex.unlock()

        guard !wasCancelled else {
            let failure = SubtensorStakingSubmissionFailure(
                stage: .notSubmitted,
                error: BaseOperationError.parentOperationCancelled
            )

            completionClosure(.failure(failure))

            return
        }

        statusKeeper.markSent()

        execute(
            wrapper: submissionWrapperClosure(),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [statusKeeper, finalizer] result in
            switch result {
            case let .success(outcome):
                completionClosure(.success(outcome))
            case let .failure(error):
                let failure = finalizer.failure(for: error)

                if failure.stage.revertsSharedOperation {
                    statusKeeper.restore()
                }

                completionClosure(.failure(failure))
            }
        }
    }

    func cancel() {
        mutex.lock()
        isCancelled = true
        mutex.unlock()
    }
}

private final class SubtensorSharedOperationStatusKeeper {
    private let sharedOperation: SharedOperationProtocol?
    private var capturedStatus: SharedOperationStatus?

    init(sharedOperation: SharedOperationProtocol?) {
        self.sharedOperation = sharedOperation
    }

    func markSent() {
        DispatchQueue.main.async { [self] in
            capturedStatus = sharedOperation?.status
            sharedOperation?.markSent()
        }
    }

    func restore() {
        DispatchQueue.main.async { [self] in
            guard let capturedStatus else {
                return
            }

            sharedOperation?.status = capturedStatus
        }
    }
}

private final class SubtensorRecordingSigner: SigningWrapperProtocol {
    private let signer: SigningWrapperProtocol
    private let mutex = NSLock()

    private var signatureCreated = false

    init(signer: SigningWrapperProtocol) {
        self.signer = signer
    }

    var hasSignature: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return signatureCreated
    }

    func sign(_ originalData: Data, context: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        let signature = try signer.sign(originalData, context: context)

        mutex.lock()
        signatureCreated = true
        mutex.unlock()

        return signature
    }
}

private struct SubtensorStakingSubmissionFinalizer {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let novaFeeBeneficiary: AccountId?
    let signer: SubtensorRecordingSigner
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol?
    let eventCenter: EventCenterProtocol
    let errorMapper: SubtensorStakingErrorMapping

    func failure(for error: Error) -> SubtensorStakingSubmissionFailure {
        if let failure = error as? SubtensorStakingSubmissionFailure {
            return failure
        }

        let mappedError = errorMapper.mapSubmission(error: error)

        guard signer.hasSignature, !Self.isFirstSendRejection(mappedError) else {
            return SubtensorStakingSubmissionFailure(stage: .notSubmitted, error: mappedError)
        }

        notifyStakingChanged()

        return SubtensorStakingSubmissionFailure(stage: .unconfirmed(extrinsicHash: nil), error: mappedError)
    }

    func dispatchFailure(for failure: SubstrateExtrinsicStatus.FailedExtrinsic) -> SubtensorStakingSubmissionFailure {
        SubtensorStakingSubmissionFailure(
            stage: .dispatched(blockHash: failure.blockHash, extrinsicHash: failure.extrinsicHash),
            error: errorMapper.mapSubmission(error: failure.error)
        )
    }

    func complete(
        operation: SubtensorStakingOperation,
        success: SubstrateExtrinsicStatus.SuccessExtrinsic,
        codingFactory: RuntimeCoderFactoryProtocol?
    ) throws -> SubtensorStakingOperationOutcome {
        let outcome: SubtensorStakingOperationOutcome

        if let codingFactory {
            let parser = SubtensorStakingOutcomeParser(
                coldkey: accountId,
                novaFeeBeneficiary: novaFeeBeneficiary,
                codingFactory: codingFactory
            )

            do {
                outcome = try parser.parse(
                    events: success.interestedEvents,
                    for: operation,
                    extrinsicHash: success.extrinsicHash,
                    blockHash: success.blockHash
                )
            } catch {
                throw SubtensorStakingSubmissionFailure(
                    stage: .dispatched(blockHash: success.blockHash, extrinsicHash: success.extrinsicHash),
                    error: errorMapper.mapSubmission(error: error)
                )
            }
        } else {
            outcome = SubtensorStakingOperationOutcome(
                executed: nil,
                novaFeePaid: nil,
                alphaFeePaid: nil,
                networkFeePaid: nil,
                extrinsicHash: success.extrinsicHash,
                blockHash: success.blockHash
            )
        }

        notifyStakingChanged()

        return outcome
    }
}

private extension SubtensorStakingSubmissionFinalizer {
    static func isFirstSendRejection(_ error: Error) -> Bool {
        switch error as? SubtensorStakingSubmissionError {
        case .feeUnpayable, .coldkeySwapInProgress:
            true
        default:
            false
        }
    }

    func notifyStakingChanged() {
        positionsSyncService?.refresh()
        eventCenter.notify(with: SubtensorStakingChanged(chainAssetId: chainAssetId, accountId: accountId))
    }
}

private extension SubtensorStakingSubmissionFailure.Stage {
    var revertsSharedOperation: Bool {
        switch self {
        case .notSubmitted, .dispatched:
            true
        case .unconfirmed:
            false
        }
    }
}

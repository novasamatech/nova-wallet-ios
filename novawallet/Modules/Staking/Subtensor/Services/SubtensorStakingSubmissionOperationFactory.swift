import Foundation
import Operation_iOS
import SubstrateSdk

final class SubtensorStakingSubmissionOperationFactory {
    let chainAsset: ChainAsset
    let accountId: AccountId
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    let signer: SigningWrapperProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let sharedOperation: SharedOperationProtocol?
    let eventCenter: EventCenterProtocol
    let configProvider: SubtensorConfigProviding
    let pendingRootClaims: SubtensorPendingRootClaimsProtocol?
    let errorMapper: SubtensorStakingErrorMapping = SubtensorStakingErrorMapper()
    let feeCalculator: SubtensorNovaFeeCalculator
    let workingQueue = DispatchQueue.global(qos: .userInitiated)

    init(
        chainAsset: ChainAsset,
        accountId: AccountId,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signer: SigningWrapperProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        sharedOperation: SharedOperationProtocol?,
        eventCenter: EventCenterProtocol,
        configProvider: SubtensorConfigProviding,
        pendingRootClaims: SubtensorPendingRootClaimsProtocol? = nil,
        feeCalculator: SubtensorNovaFeeCalculator = SubtensorNovaFeeCalculator()
    ) {
        self.chainAsset = chainAsset
        self.accountId = accountId
        self.extrinsicService = extrinsicService
        self.extrinsicSubmitMonitor = extrinsicSubmitMonitor
        self.signer = signer
        self.runtimeProvider = runtimeProvider
        self.sharedOperation = sharedOperation
        self.eventCenter = eventCenter
        self.configProvider = configProvider
        self.pendingRootClaims = pendingRootClaims
        self.feeCalculator = feeCalculator
    }
}

private extension SubtensorStakingSubmissionOperationFactory {
    func createFinalizer(signer: SubtensorRecordingSigner) -> SubtensorStakingSubmissionFinalizer {
        SubtensorStakingSubmissionFinalizer(
            chainAssetId: chainAsset.chainAssetId,
            accountId: accountId,
            novaFeeBeneficiary: feeCalculator.beneficiary,
            signer: signer,
            eventCenter: eventCenter,
            errorMapper: errorMapper
        )
    }

    func createEstimateOperation(
        resolving operationClosure: @escaping () throws -> SubtensorStakingOperation
    ) -> BaseOperation<ExtrinsicFeeProtocol> {
        AsyncClosureOperation { [extrinsicService, workingQueue, feeCalculator] completion in
            let builderClosure = try operationClosure().extrinsicBuilderClosure(
                novaFeeBeneficiary: feeCalculator.beneficiary
            )

            extrinsicService.estimateFee(builderClosure, runningIn: workingQueue) { result in
                completion(result)
            }
        }
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

                return finalizer.complete(operation: operation, success: success, codingFactory: codingFactory)
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

extension SubtensorStakingSubmissionOperationFactory: SubtensorStakingSubmissionOperationFactoryProtocol {
    func createFeeWrapper(
        for operation: SubtensorStakingOperation
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        guard let basis = operation.novaFeeBasis, operation.novaFee == nil else {
            return CompoundOperationWrapper(targetOperation: createEstimateOperation { operation })
        }

        let rateWrapper = configProvider.createNovaFeeRateWrapper()

        let estimateOperation = createEstimateOperation { [feeCalculator] in
            let rate = try rateWrapper.targetOperation.extractNoCancellableResultData()

            return try operation.pricing(novaFee: feeCalculator.fee(basis: basis, rate: rate))
        }

        estimateOperation.addDependency(rateWrapper.targetOperation)

        return rateWrapper.insertingTail(operation: estimateOperation)
    }

    func createSubmitWrapper(
        for operation: SubtensorStakingOperation,
        signedClosure: @escaping () -> Void
    ) -> CompoundOperationWrapper<SubtensorStakingOperationOutcome> {
        let builderClosure: ExtrinsicBuilderClosure

        do {
            builderClosure = try operation.extrinsicBuilderClosure(novaFeeBeneficiary: feeCalculator.beneficiary)
        } catch {
            return .createWithError(SubtensorStakingSubmissionFailure(stage: .notSubmitted, error: error))
        }

        let claimMarker = pendingRootClaims?.marker(for: operation, coldkey: accountId)

        let recordingSigner = SubtensorRecordingSigner(signer: signer) {
            claimMarker?.markSigned()
            signedClosure()
        }

        let finalizer = createFinalizer(signer: recordingSigner)

        let markSentOperation = ClosureOperation { [sharedOperation] in
            DispatchQueue.main.async {
                sharedOperation?.markSent()
            }
        }

        let submissionWrapper = createSubmissionWrapper(
            for: operation,
            builderClosure: builderClosure,
            signer: recordingSigner,
            finalizer: finalizer
        )

        submissionWrapper.addDependency(operations: [markSentOperation])

        let resultOperation = ClosureOperation<SubtensorStakingOperationOutcome> { [sharedOperation] in
            do {
                let outcome = try submissionWrapper.targetOperation.extractNoCancellableResultData()
                claimMarker?.finish()
                return outcome
            } catch {
                let failure = finalizer.failure(for: error)

                claimMarker?.finish(failedAt: failure.stage)

                if failure.stage.revertsSharedOperation {
                    DispatchQueue.main.async {
                        sharedOperation?.markComposing()
                    }
                }

                throw failure
            }
        }

        resultOperation.addDependency(submissionWrapper.targetOperation)

        return submissionWrapper
            .insertingHead(operations: [markSentOperation])
            .insertingTail(operation: resultOperation)
    }
}

private struct SubtensorStakingSubmissionFinalizer {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let novaFeeBeneficiary: AccountId?
    let signer: SubtensorRecordingSigner
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
    ) -> SubtensorStakingOperationOutcome {
        let outcome: SubtensorStakingOperationOutcome

        if let codingFactory {
            let parser = SubtensorStakingOutcomeParser(
                coldkey: accountId,
                novaFeeBeneficiary: novaFeeBeneficiary,
                codingFactory: codingFactory
            )

            outcome = parser.parse(
                events: success.interestedEvents,
                for: operation,
                extrinsicHash: success.extrinsicHash,
                blockHash: success.blockHash
            )
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

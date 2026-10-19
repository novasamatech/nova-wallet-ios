import Foundation
import Operation_iOS
import SubstrateSdk

final class SubtensorSubmissionOperationFactory {
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
    let errorMapper: SubtensorErrorMapping = SubtensorErrorMapper()
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

private extension SubtensorSubmissionOperationFactory {
    func createFinalizer(
        for operation: SubtensorOperation,
        signer: SubtensorRecordingSigner
    ) -> SubtensorSubmissionFinalizer {
        SubtensorSubmissionFinalizer(
            chainAssetId: chainAsset.chainAssetId,
            accountId: accountId,
            netuids: operation.netuids,
            novaFeeBeneficiary: feeCalculator.beneficiary,
            signer: signer,
            eventCenter: eventCenter,
            errorMapper: errorMapper
        )
    }

    func createEstimateOperation(
        resolving operationClosure: @escaping () throws -> SubtensorOperation
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
        for operation: SubtensorOperation,
        builderClosure: @escaping ExtrinsicBuilderClosure,
        signer: SubtensorRecordingSigner,
        finalizer: SubtensorSubmissionFinalizer
    ) -> CompoundOperationWrapper<SubtensorOperationOutcome> {
        let submitWrapper = extrinsicSubmitMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: builderClosure,
            payingIn: nil,
            signer: signer,
            matchingEvents: SubtensorEventMatcher()
        )

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let outcomeOperation = ClosureOperation<SubtensorOperationOutcome> {
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

extension SubtensorSubmissionOperationFactory: SubtensorSubmissionOperationFactoryProtocol {
    func createFeeWrapper(
        for operation: SubtensorOperation
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
        for operation: SubtensorOperation,
        signedClosure: @escaping () -> Void
    ) -> CompoundOperationWrapper<SubtensorOperationOutcome> {
        let builderClosure: ExtrinsicBuilderClosure

        do {
            builderClosure = try operation.extrinsicBuilderClosure(novaFeeBeneficiary: feeCalculator.beneficiary)
        } catch {
            return .createWithError(SubtensorSubmissionFailure(stage: .notSubmitted, error: error))
        }

        let claimMarker = pendingRootClaims?.marker(for: operation, coldkey: accountId)

        let recordingSigner = SubtensorRecordingSigner(signer: signer) {
            claimMarker?.markSigned()
            signedClosure()
        }

        let finalizer = createFinalizer(for: operation, signer: recordingSigner)

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

        let resultOperation = ClosureOperation<SubtensorOperationOutcome> { [sharedOperation] in
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

private struct SubtensorSubmissionFinalizer {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let netuids: Set<UInt16>
    let novaFeeBeneficiary: AccountId?
    let signer: SubtensorRecordingSigner
    let eventCenter: EventCenterProtocol
    let errorMapper: SubtensorErrorMapping

    func failure(for error: Error) -> SubtensorSubmissionFailure {
        if let failure = error as? SubtensorSubmissionFailure {
            return failure
        }

        let mappedError = errorMapper.mapSubmission(error: error)

        guard signer.hasSignature, !Self.isFirstSendRejection(mappedError) else {
            return SubtensorSubmissionFailure(stage: .notSubmitted, error: mappedError)
        }

        notifyStakeChanged()

        return SubtensorSubmissionFailure(stage: .unconfirmed(extrinsicHash: nil), error: mappedError)
    }

    func dispatchFailure(for failure: SubstrateExtrinsicStatus.FailedExtrinsic) -> SubtensorSubmissionFailure {
        SubtensorSubmissionFailure(
            stage: .dispatched(blockHash: failure.blockHash, extrinsicHash: failure.extrinsicHash),
            error: errorMapper.mapSubmission(error: failure.error)
        )
    }

    func complete(
        operation: SubtensorOperation,
        success: SubstrateExtrinsicStatus.SuccessExtrinsic,
        codingFactory: RuntimeCoderFactoryProtocol?
    ) -> SubtensorOperationOutcome {
        let outcome: SubtensorOperationOutcome

        if let codingFactory {
            let parser = SubtensorOutcomeParser(
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
            outcome = SubtensorOperationOutcome(
                executed: nil,
                novaFeePaid: nil,
                alphaFeePaid: nil,
                networkFeePaid: nil,
                extrinsicHash: success.extrinsicHash,
                blockHash: success.blockHash
            )
        }

        notifyStakeChanged()

        return outcome
    }
}

private extension SubtensorSubmissionFinalizer {
    static func isFirstSendRejection(_ error: Error) -> Bool {
        switch error as? SubtensorSubmissionError {
        case .feeUnpayable, .coldkeySwapInProgress:
            true
        default:
            false
        }
    }

    func notifyStakeChanged() {
        eventCenter.notify(
            with: SubtensorStakeChanged(chainAssetId: chainAssetId, accountId: accountId, netuids: netuids)
        )
    }
}

private extension SubtensorSubmissionFailure.Stage {
    var revertsSharedOperation: Bool {
        switch self {
        case .notSubmitted, .dispatched:
            true
        case .unconfirmed:
            false
        }
    }
}

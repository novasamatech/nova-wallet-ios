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
    let shield: SubtensorShieldServices?
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
        feeCalculator: SubtensorNovaFeeCalculator = SubtensorNovaFeeCalculator(),
        shield: SubtensorShieldServices? = nil
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
        self.shield = shield
    }
}

private extension SubtensorSubmissionOperationFactory {
    func createFinalizer(
        for operation: SubtensorOperation,
        submissionMarkers: [SubtensorRecordingSigner]
    ) -> SubtensorSubmissionFinalizer {
        SubtensorSubmissionFinalizer(
            chainAssetId: chainAsset.chainAssetId,
            accountId: accountId,
            netuids: operation.netuids,
            novaFeeBeneficiary: feeCalculator.beneficiary,
            submissionMarkers: submissionMarkers,
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

    func createRoutedSubmissionWrapper(
        for operation: SubtensorOperation,
        builderClosure: @escaping ExtrinsicBuilderClosure,
        clearSigner: SubtensorRecordingSigner,
        shieldSigners: SubtensorShieldSigners?,
        finalizer: SubtensorSubmissionFinalizer
    ) -> CompoundOperationWrapper<SubtensorOperationOutcome> {
        guard let shield, let shieldSigners else {
            return createSubmissionWrapper(
                for: operation,
                builderClosure: builderClosure,
                signer: clearSigner,
                finalizer: finalizer
            )
        }

        let availabilityWrapper = shield.submissionFactory.createAvailabilityWrapper()

        let submissionWrapper = OperationCombiningService<SubtensorOperationOutcome>.compoundNonOptionalWrapper(
            operationQueue: shield.operationQueue
        ) {
            guard try availabilityWrapper.targetOperation.extractNoCancellableResultData() else {
                return self.createSubmissionWrapper(
                    for: operation,
                    builderClosure: builderClosure,
                    signer: clearSigner,
                    finalizer: finalizer
                )
            }

            return self.createShieldedSubmissionWrapper(
                for: operation,
                builderClosure: builderClosure,
                signers: shieldSigners,
                finalizer: finalizer,
                submissionFactory: shield.submissionFactory
            )
        }

        submissionWrapper.addDependency(wrapper: availabilityWrapper)

        return submissionWrapper.insertingHead(operations: availabilityWrapper.allOperations)
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
        shielded: Bool,
        signedClosure: @escaping () -> Void
    ) -> CompoundOperationWrapper<SubtensorOperationOutcome> {
        let builderClosure: ExtrinsicBuilderClosure

        do {
            builderClosure = try operation.extrinsicBuilderClosure(novaFeeBeneficiary: feeCalculator.beneficiary)
        } catch {
            return .createWithError(SubtensorSubmissionFailure(stage: .notSubmitted, error: error))
        }

        let claimMarker = pendingRootClaims?.marker(for: operation, coldkey: accountId)

        let markSigned: () -> Void = {
            claimMarker?.markSigned()
            signedClosure()
        }

        let recordingSigner = SubtensorRecordingSigner(signer: signer, signedClosure: markSigned)

        let shieldSigners = shielded ? createShieldSigners(for: operation, signedClosure: markSigned) : nil

        let finalizer = createFinalizer(
            for: operation,
            submissionMarkers: [recordingSigner] + (shieldSigners.map { [$0.carrier] } ?? [])
        )

        let markSentOperation = ClosureOperation { [sharedOperation] in
            DispatchQueue.main.async {
                sharedOperation?.markSent()
            }
        }

        let submissionWrapper = createRoutedSubmissionWrapper(
            for: operation,
            builderClosure: builderClosure,
            clearSigner: recordingSigner,
            shieldSigners: shieldSigners,
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

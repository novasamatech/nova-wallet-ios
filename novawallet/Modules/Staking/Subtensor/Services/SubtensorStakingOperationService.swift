import Foundation
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
        self.workingQueue = workingQueue
    }
}

private extension SubtensorStakingOperationService {
    func createMarkSentOperation() -> ClosureOperation<Void> {
        ClosureOperation { [sharedOperation] in
            DispatchQueue.main.async {
                sharedOperation?.markSent()
            }
        }
    }

    func createOutcomeOperation(
        for operation: SubtensorStakingOperation,
        submissionOperation: BaseOperation<ExtrinsicMonitorSubmission>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> ClosureOperation<SubtensorStakingOperationOutcome> {
        let finalizer = SubtensorStakingSubmissionFinalizer(
            chainAssetId: chainAsset.chainAssetId,
            accountId: accountId,
            novaFeeBeneficiary: feeCalculator.beneficiary,
            positionsSyncService: positionsSyncService,
            sharedOperation: sharedOperation,
            eventCenter: eventCenter,
            errorMapper: errorMapper
        )

        return ClosureOperation {
            let submission: ExtrinsicMonitorSubmission

            do {
                submission = try submissionOperation.extractNoCancellableResultData()
            } catch {
                throw finalizer.fail(with: error)
            }

            switch submission.status {
            case let .success(success):
                let codingFactory = try? codingFactoryOperation.extractNoCancellableResultData()

                return try finalizer.complete(operation: operation, success: success, codingFactory: codingFactory)
            case let .failure(failure):
                throw finalizer.fail(with: failure.error)
            }
        }
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
            return .createWithError(error)
        }

        let markSentOperation = createMarkSentOperation()

        let submitWrapper = extrinsicSubmitMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: builderClosure,
            payingIn: nil,
            signer: signer,
            matchingEvents: SubtensorStakingEventMatcher()
        )

        submitWrapper.addDependency(operations: [markSentOperation])

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let outcomeOperation = createOutcomeOperation(
            for: operation,
            submissionOperation: submitWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation
        )

        outcomeOperation.addDependency(submitWrapper.targetOperation)
        outcomeOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: outcomeOperation,
            dependencies: [markSentOperation] + submitWrapper.allOperations + [codingFactoryOperation]
        )
    }
}

private struct SubtensorStakingSubmissionFinalizer {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let novaFeeBeneficiary: AccountId?
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol?
    let sharedOperation: SharedOperationProtocol?
    let eventCenter: EventCenterProtocol
    let errorMapper: SubtensorStakingErrorMapping

    func fail(with error: Error) -> Error {
        let sharedOperation = sharedOperation

        DispatchQueue.main.async {
            sharedOperation?.markComposing()
        }

        return errorMapper.mapSubmission(error: error)
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
                    extrinsicHash: success.extrinsicHash
                )
            } catch {
                throw fail(with: error)
            }
        } else {
            outcome = SubtensorStakingOperationOutcome(
                executed: nil,
                claimedTao: nil,
                novaFeePaid: nil,
                alphaFeePaid: nil,
                extrinsicHash: success.extrinsicHash
            )
        }

        positionsSyncService?.refresh()
        eventCenter.notify(with: SubtensorStakingChanged(chainAssetId: chainAssetId, accountId: accountId))

        return outcome
    }
}

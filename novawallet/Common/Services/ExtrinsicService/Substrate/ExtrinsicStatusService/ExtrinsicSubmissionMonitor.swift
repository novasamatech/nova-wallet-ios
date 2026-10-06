import Foundation
import Operation_iOS
import SubstrateSdk

protocol ExtrinsicSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        payingIn feeAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<ExtrinsicMonitorSubmission>
}

extension ExtrinsicSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        payingIn feeAssetId: ChainAssetId? = nil,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<ExtrinsicMonitorSubmission> {
        submitAndMonitorWrapper(
            extrinsicBuilderClosure: extrinsicBuilderClosure,
            payingIn: feeAssetId,
            signer: signer,
            matchingEvents: nil
        )
    }
}

enum ExtrinsicSubmissionMonitorError: Error, Equatable {
    case invalid
    case dropped
    case usurped(ExtrinsicHash)
}

extension ExtrinsicSubmissionMonitorError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return ErrorContent(title: strings.commonErrorGeneralTitle(), message: strings.commonTransactionFailed())
    }
}

final class ExtrinsicSubmissionMonitorFactory {
    struct SubmissionResult {
        let blockHash: BlockHash
        let extrinsicHash: ExtrinsicHash
        let sender: ExtrinsicSenderResolution
    }

    let submissionService: ExtrinsicServiceProtocol
    let statusService: ExtrinsicStatusServiceProtocol
    let operationQueue: OperationQueue
    let processingQueue = DispatchQueue(label: "io.novawallet.extrinsic.monitor.\(UUID().uuidString)")

    init(
        submissionService: ExtrinsicServiceProtocol,
        statusService: ExtrinsicStatusServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.submissionService = submissionService
        self.statusService = statusService
        self.operationQueue = operationQueue
    }

    convenience init(
        submissionService: ExtrinsicServiceProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        let statusService = ExtrinsicStatusService(
            connection: connection,
            runtimeProvider: runtimeService,
            eventsQueryFactory: BlockEventsQueryFactory(operationQueue: operationQueue),
            logger: logger
        )

        self.init(submissionService: submissionService, statusService: statusService, operationQueue: operationQueue)
    }
}

extension ExtrinsicSubmissionMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        payingIn feeAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<ExtrinsicMonitorSubmission> {
        let submissionOperation = createSubmissionOperation(
            extrinsicBuilderClosure: extrinsicBuilderClosure,
            payingIn: feeAssetId,
            signer: signer
        )

        let statusWrapper: CompoundOperationWrapper<SubstrateExtrinsicStatus> = OperationCombiningService
            .compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let response = try submissionOperation.extractNoCancellableResultData()

                return self.statusService.fetchExtrinsicStatusForHash(
                    response.extrinsicHash,
                    inBlock: response.blockHash,
                    matchingEvents: matchingEvents
                )
            }

        statusWrapper.addDependency(operations: [submissionOperation])

        let mappingOperation = ClosureOperation<ExtrinsicMonitorSubmission> {
            let status = try statusWrapper.targetOperation.extractNoCancellableResultData()
            let submission = try submissionOperation.extractNoCancellableResultData()

            return ExtrinsicMonitorSubmission(
                extrinsicSubmittedModel: ExtrinsicSubmittedModel(
                    txHash: submission.extrinsicHash,
                    sender: submission.sender
                ),
                status: status
            )
        }

        mappingOperation.addDependency(statusWrapper.targetOperation)

        return statusWrapper
            .insertingHead(operations: [submissionOperation])
            .insertingTail(operation: mappingOperation)
    }
}

private extension ExtrinsicSubmissionMonitorFactory {
    func createSubmissionOperation(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        payingIn feeAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol
    ) -> AsyncClosureOperation<SubmissionResult> {
        var subscriptionId: UInt16?

        return AsyncClosureOperation<SubmissionResult>(operationClosure: { completionClosure in
            self.submissionService.submitAndWatch(
                extrinsicBuilderClosure,
                payingIn: feeAssetId,
                signer: signer,
                runningIn: self.processingQueue,
                subscriptionIdClosure: { identifier in
                    subscriptionId = identifier

                    return true
                },
                notificationClosure: { result in
                    guard let submissionResult = self.submissionResult(from: result) else {
                        return
                    }

                    if let subscriptionId {
                        self.submissionService.cancelExtrinsicWatch(for: subscriptionId)
                    }

                    completionClosure(submissionResult)
                }
            )
        }, cancelationClosure: {
            self.processingQueue.async {
                guard let subscriptionId else {
                    return
                }

                self.submissionService.cancelExtrinsicWatch(for: subscriptionId)
            }
        })
    }

    func submissionResult(
        from result: Result<ExtrinsicSubscribedStatusModel, Error>
    ) -> Result<SubmissionResult, Error>? {
        switch result {
        case let .success(model):
            if let blockHash = model.statusUpdate.getInBlockOrFinalizedHash() {
                let response = SubmissionResult(
                    blockHash: blockHash,
                    extrinsicHash: model.statusUpdate.extrinsicHash,
                    sender: model.sender
                )

                return .success(response)
            } else if let error = model.statusUpdate.extrinsicStatus.notIncludedError {
                return .failure(error)
            } else {
                return nil
            }
        case let .failure(error):
            return .failure(error)
        }
    }
}

private extension ExtrinsicStatus {
    var notIncludedError: ExtrinsicSubmissionMonitorError? {
        switch self {
        case .invalid:
            .invalid
        case .dropped:
            .dropped
        case let .usurped(extrinsicHash):
            .usurped(extrinsicHash)
        default:
            nil
        }
    }
}

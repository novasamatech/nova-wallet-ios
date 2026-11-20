import Foundation
import Operation_iOS
import SubstrateSdk

enum ExtrinsicMonitorCompletion {
    case inBlock
    case finalized
}

struct ExtrinsicSubmitMonitorWrapper {
    let submissionOperation: BaseOperation<ExtrinsicSubmittedModel>
    let monitorWrapper: CompoundOperationWrapper<ExtrinsicMonitorSubmission>
}

protocol ExtrinsicSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        payingIn feeAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol,
        matchingEvents: ExtrinsicEventsMatching?,
        completingOn completion: ExtrinsicMonitorCompletion
    ) -> ExtrinsicSubmitMonitorWrapper
}

extension ExtrinsicSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        payingIn feeAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<ExtrinsicMonitorSubmission> {
        submitAndMonitorWrapper(
            extrinsicBuilderClosure: extrinsicBuilderClosure,
            payingIn: feeAssetId,
            signer: signer,
            matchingEvents: matchingEvents,
            completingOn: .inBlock
        ).monitorWrapper
    }

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

extension FinalExtrinsicStatusError: ErrorContentConvertible {
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
        matchingEvents: ExtrinsicEventsMatching?,
        completingOn completion: ExtrinsicMonitorCompletion
    ) -> ExtrinsicSubmitMonitorWrapper {
        let inclusionStore = ExtrinsicInclusionStore()

        let watchOperation = createSubmissionOperation(
            extrinsicBuilderClosure: extrinsicBuilderClosure,
            payingIn: feeAssetId,
            signer: signer,
            completingOn: completion,
            inclusionStore: inclusionStore
        )

        let submittedOperation = ClosureOperation<ExtrinsicSubmittedModel> {
            do {
                let submission = try watchOperation.extractNoCancellableResultData()

                return ExtrinsicSubmittedModel(txHash: submission.extrinsicHash, sender: submission.sender)
            } catch {
                guard let includedModel = inclusionStore.fetchModel() else {
                    throw error
                }

                return includedModel
            }
        }

        submittedOperation.addDependency(watchOperation)

        let statusWrapper: CompoundOperationWrapper<SubstrateExtrinsicStatus> = OperationCombiningService
            .compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let response = try watchOperation.extractNoCancellableResultData()

                return self.statusService.fetchExtrinsicStatusForHash(
                    response.extrinsicHash,
                    inBlock: response.blockHash,
                    matchingEvents: matchingEvents
                )
            }

        statusWrapper.addDependency(operations: [watchOperation])

        let mappingOperation = ClosureOperation<ExtrinsicMonitorSubmission> {
            let status = try statusWrapper.targetOperation.extractNoCancellableResultData()
            let submittedModel = try submittedOperation.extractNoCancellableResultData()

            return ExtrinsicMonitorSubmission(extrinsicSubmittedModel: submittedModel, status: status)
        }

        mappingOperation.addDependency(statusWrapper.targetOperation)
        mappingOperation.addDependency(submittedOperation)

        let monitorWrapper = statusWrapper
            .insertingHead(operations: [watchOperation, submittedOperation])
            .insertingTail(operation: mappingOperation)

        return ExtrinsicSubmitMonitorWrapper(submissionOperation: submittedOperation, monitorWrapper: monitorWrapper)
    }
}

private extension ExtrinsicSubmissionMonitorFactory {
    func createSubmissionOperation(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        payingIn feeAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol,
        completingOn completion: ExtrinsicMonitorCompletion,
        inclusionStore: ExtrinsicInclusionStore
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
                    guard
                        let submissionResult = self.submissionResult(from: result, completingOn: completion) else {
                        if case let .success(model) = result, case .inBlock = model.statusUpdate.extrinsicStatus {
                            inclusionStore.store(model: model.extrinsicSubmittedModel)
                        }

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

    func completionBlockHash(
        from statusUpdate: ExtrinsicStatusUpdate,
        completingOn completion: ExtrinsicMonitorCompletion
    ) -> BlockHash? {
        switch completion {
        case .inBlock:
            statusUpdate.getInBlockOrFinalizedHash()
        case .finalized:
            statusUpdate.getFinalizedHash()
        }
    }

    func submissionResult(
        from result: Result<ExtrinsicSubscribedStatusModel, Error>,
        completingOn completion: ExtrinsicMonitorCompletion
    ) -> Result<SubmissionResult, Error>? {
        switch result {
        case let .success(model):
            if let blockHash = completionBlockHash(from: model.statusUpdate, completingOn: completion) {
                let response = SubmissionResult(
                    blockHash: blockHash,
                    extrinsicHash: model.statusUpdate.extrinsicHash,
                    sender: model.sender
                )

                return .success(response)
            } else if let failure = model.statusUpdate.getFinalExtrinsicFailure() {
                return .failure(failure)
            } else {
                return nil
            }
        case let .failure(error):
            return .failure(error)
        }
    }
}

private final class ExtrinsicInclusionStore {
    private let mutex = NSLock()
    private var model: ExtrinsicSubmittedModel?

    func store(model: ExtrinsicSubmittedModel) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        self.model = model
    }

    func fetchModel() -> ExtrinsicSubmittedModel? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return model
    }
}

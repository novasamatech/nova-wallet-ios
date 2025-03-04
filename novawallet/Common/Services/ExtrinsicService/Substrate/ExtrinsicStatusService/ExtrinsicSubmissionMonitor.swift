import Foundation
import Operation_iOS

protocol ExtrinsicSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        payingIn feeAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus>
}

extension ExtrinsicSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        payingIn feeAssetId: ChainAssetId? = nil,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus> {
        submitAndMonitorWrapper(
            extrinsicBuilderClosure: extrinsicBuilderClosure,
            payingIn: feeAssetId,
            signer: signer,
            matchingEvents: nil
        )
    }
}

final class ExtrinsicSubmissionMonitorFactory {
    struct SubmissionResult {
        let blockHash: String
        let extrinsicHash: String
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
}

extension ExtrinsicSubmissionMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        payingIn feeAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus> {
        var subscriptionId: UInt16?

        let submissionOperation = AsyncClosureOperation<SubmissionResult>(operationClosure: { completionClosure in
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
                    switch result {
                    case let .success(model):
                        if let blockHash = model.getInBlockOrFinalizedHash() {
                            if let subscriptionId {
                                self.submissionService.cancelExtrinsicWatch(for: subscriptionId)
                            }

                            let response = SubmissionResult(
                                blockHash: blockHash,
                                extrinsicHash: model.extrinsicHash
                            )

                            completionClosure(.success(response))
                        }
                    case let .failure(error):
                        if let subscriptionId {
                            self.submissionService.cancelExtrinsicWatch(for: subscriptionId)
                        }

                        completionClosure(.failure(error))
                    }
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

        return statusWrapper.insertingHead(operations: [submissionOperation])
    }
}

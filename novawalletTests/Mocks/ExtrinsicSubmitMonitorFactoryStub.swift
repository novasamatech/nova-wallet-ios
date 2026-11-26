import Foundation
import Operation_iOS
@testable import novawallet

final class ExtrinsicSubmitMonitorFactoryStub: ExtrinsicSubmitMonitorFactoryProtocol {
    let submission: ExtrinsicMonitorSubmission

    init(submission: ExtrinsicMonitorSubmission) {
        self.submission = submission
    }

    func submitAndMonitorWrapper(
        extrinsicBuilderClosure _: @escaping ExtrinsicBuilderClosure,
        payingIn _: ChainAssetId?,
        signer _: SigningWrapperProtocol,
        matchingEvents _: ExtrinsicEventsMatching?,
        completingOn _: ExtrinsicMonitorCompletion
    ) -> ExtrinsicSubmitMonitorWrapper {
        .stub { self.submission }
    }
}

extension ExtrinsicSubmitMonitorWrapper {
    static func stub(
        _ submissionClosure: @escaping () throws -> ExtrinsicMonitorSubmission
    ) -> ExtrinsicSubmitMonitorWrapper {
        let watchOperation = ClosureOperation<ExtrinsicMonitorSubmission>(closure: submissionClosure)

        let submissionOperation = ClosureOperation<ExtrinsicSubmittedModel> {
            try watchOperation.extractNoCancellableResultData().extrinsicSubmittedModel
        }

        submissionOperation.addDependency(watchOperation)

        let monitorOperation = ClosureOperation<ExtrinsicMonitorSubmission> {
            try watchOperation.extractNoCancellableResultData()
        }

        monitorOperation.addDependency(submissionOperation)

        return ExtrinsicSubmitMonitorWrapper(
            submissionOperation: submissionOperation,
            monitorWrapper: CompoundOperationWrapper(
                targetOperation: monitorOperation,
                dependencies: [watchOperation, submissionOperation]
            )
        )
    }
}

extension ExtrinsicSubmitMonitorFactoryStub {
    static func dummy() -> ExtrinsicSubmitMonitorFactoryStub {
        let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)

        let chainAccount = AccountGenerator.generateSubstrateChainAccountResponse(
            for: KnowChainId.westend
        )

        let submittedModel = ExtrinsicSubmittedModel(
            txHash: txHash,
            sender: .current(chainAccount)
        )

        let blockHash = Data(repeating: 8, count: 32).toHex(includePrefix: true)

        let status = SubstrateExtrinsicStatus.success(
            .init(
                extrinsicHash: txHash,
                blockHash: blockHash,
                interestedEvents: []
            )
        )

        let submission = ExtrinsicMonitorSubmission(
            extrinsicSubmittedModel: submittedModel,
            status: status
        )

        return ExtrinsicSubmitMonitorFactoryStub(submission: submission)
    }
}

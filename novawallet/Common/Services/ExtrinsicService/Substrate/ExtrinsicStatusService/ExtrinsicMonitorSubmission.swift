import Foundation

struct ExtrinsicMonitorSubmission {
    let extrinsicSubmittedModel: ExtrinsicSubmittedModel
    let status: SubstrateExtrinsicStatus
}

extension Result where Success == ExtrinsicMonitorSubmission {
    func getSuccessSubmittedModel() throws -> ExtrinsicSubmittedModel {
        let submission = try get()

        switch submission.status {
        case let .success:
            return submission.extrinsicSubmittedModel
        case let .failure(failureStature):
            throw failureStature.error
        }
    }
}

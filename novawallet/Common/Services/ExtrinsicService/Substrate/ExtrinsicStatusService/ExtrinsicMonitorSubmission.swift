import Foundation

struct ExtrinsicMonitorSubmission {
    let extrinsicSubmittedModel: ExtrinsicSubmittedModel
    let status: SubstrateExtrinsicStatus
}

extension Result where Success == ExtrinsicMonitorSubmission {
    func getSuccessSubmittedModel() throws -> ExtrinsicSubmittedModel {
        let submission = try get()

        switch submission.status {
        case .success:
            return submission.extrinsicSubmittedModel
        case let .failure(failureStature):
            throw failureStature.error
        }
    }

    func mapToExtrinsicSubmittedResult() -> SubmitExtrinsicResult {
        do {
            let mapped = try getSuccessSubmittedModel()

            return .success(mapped)
        } catch {
            return .failure(error)
        }
    }
}

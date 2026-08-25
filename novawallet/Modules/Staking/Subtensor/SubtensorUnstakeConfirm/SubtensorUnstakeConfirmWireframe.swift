import Foundation

final class SubtensorUnstakeConfirmWireframe: SubtensorUnstakeConfirmWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func complete(
        on view: CollatorStkUnstakeConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        title: ExtrinsicSubmissionPresentingParams.Title
    ) {
        let params = ExtrinsicSubmissionPresentingParams(
            title: title,
            sender: sender,
            preferredCompletionAction: .dismiss
        )

        presentExtrinsicSubmission(from: view, params: params)
    }
}

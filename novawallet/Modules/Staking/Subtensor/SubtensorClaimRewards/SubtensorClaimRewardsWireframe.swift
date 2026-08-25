import Foundation

final class SubtensorClaimRewardsWireframe: SubtensorClaimRewardsWireframeProtocol {
    func complete(
        on view: StakingGenericRewardsViewProtocol?,
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

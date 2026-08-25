import Foundation

final class SubtensorStakingConfirmWireframe: SubtensorStakingConfirmWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func complete(
        on view: CollatorStakingConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        title: ExtrinsicSubmissionPresentingParams.Title
    ) {
        let navigationController = view?.controller.navigationController
        let viewControllers = navigationController?.viewControllers ?? []

        let completionAction: ExtrinsicSubmissionPresentingAction =
            viewControllers.contains { $0 is StartStakingInfoViewProtocol } ? .popBaseAndDismiss : .dismiss

        let params = ExtrinsicSubmissionPresentingParams(
            title: title,
            sender: sender,
            preferredCompletionAction: completionAction
        )

        presentExtrinsicSubmission(from: view, params: params)
    }
}

import Foundation

final class ParaStkStakeConfirmWireframe: ParaStkStakeConfirmWireframeProtocol,
    ModalAlertPresenting,
    ExtrinsicSubmissionPresenting {
    func complete(
        on view: CollatorStakingConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        locale: Locale
    ) {
        let navigationController = view?.controller.navigationController
        let viewControllers = navigationController?.viewControllers ?? []

        if viewControllers.contains(where: { $0 is StartStakingInfoViewProtocol }) {
            presentExtrinsicSubmission(
                from: view,
                sender: sender,
                completionAction: .popBaseAndDismiss,
                locale: locale
            )
        } else {
            presentExtrinsicSubmission(
                from: view,
                sender: sender,
                completionAction: .dismiss,
                locale: locale
            )
        }
    }
}

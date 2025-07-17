import Foundation

final class ParaStkStakeConfirmWireframe: ParaStkStakeConfirmWireframeProtocol,
    ModalAlertPresenting,
    ExtrinsicSubmissionPresenting {
    func complete(on view: CollatorStakingConfirmViewProtocol?, locale: Locale) {
        let navigationController = view?.controller.navigationController
        let viewControllers = navigationController?.viewControllers ?? []

        // TODO: MS navigation
        if viewControllers.contains(where: { $0 is StartStakingInfoViewProtocol }) {
            presentExtrinsicSubmission(
                from: view,
                sender: nil,
                completionAction: .popBaseAndDismiss,
                locale: locale
            )
        } else {
            presentExtrinsicSubmission(
                from: view,
                sender: nil,
                completionAction: .dismiss,
                locale: locale
            )
        }
    }
}

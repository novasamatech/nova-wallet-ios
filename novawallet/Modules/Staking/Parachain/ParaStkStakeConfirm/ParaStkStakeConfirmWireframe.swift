import Foundation

final class ParaStkStakeConfirmWireframe: ParaStkStakeConfirmWireframeProtocol,
    ModalAlertPresenting,
    ExtrinsicSubmissionPresenting {
    func complete(on view: ParaStkStakeConfirmViewProtocol?, locale: Locale) {
        let navigationController = view?.controller.navigationController
        let viewControllers = navigationController?.viewControllers ?? []

        if viewControllers.contains(where: { $0 is StartStakingInfoViewProtocol }) {
            presentExtrinsicSubmission(
                from: view,
                completionAction: .popBaseAndDismiss,
                locale: locale
            )
        } else {
            presentExtrinsicSubmission(
                from: view,
                completionAction: .dismiss,
                locale: locale
            )
        }
    }
}

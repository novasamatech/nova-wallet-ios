import Foundation

enum ExtrinsicSubmissionPresentingAction {
    case dismiss
    case pop
}

protocol ExtrinsicSubmissionPresenting: AnyObject {
    func presentExtrinsicSubmission(
        from view: ControllerBackedProtocol?,
        completionAction: ExtrinsicSubmissionPresentingAction,
        locale: Locale
    )
}

extension ExtrinsicSubmissionPresenting where Self: ModalAlertPresenting {
    func presentExtrinsicSubmission(
        from view: ControllerBackedProtocol?,
        completionAction: ExtrinsicSubmissionPresentingAction,
        locale: Locale
    ) {
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: locale.rLanguages)

        switch completionAction {
        case .dismiss:
            let presenter = view?.controller.navigationController?.presentingViewController

            presenter?.dismiss(animated: true) { [weak self] in
                self?.presentSuccessNotification(title, from: presenter, completion: nil)
            }
        case .pop:
            let presenter = view?.controller.navigationController
            view?.controller.navigationController?.popToRootViewController(animated: true)

            presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}

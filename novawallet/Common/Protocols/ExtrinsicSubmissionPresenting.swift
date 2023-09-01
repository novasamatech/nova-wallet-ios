import UIKit

enum ExtrinsicSubmissionPresentingAction {
    case dismiss
    case pop
    case popBack
    case popBaseAndDismiss
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
        case .popBack:
            let presenter = view?.controller.navigationController
            view?.controller.navigationController?.popViewController(animated: true)

            presentSuccessNotification(title, from: presenter, completion: nil)
        case .popBaseAndDismiss:
            let presenter = view?.controller.navigationController?.presentingViewController

            if let rootNavigationController = presenter as? UINavigationController {
                rootNavigationController.popToRootViewController(animated: false)
            }

            presenter?.dismiss(animated: true) { [weak self] in
                self?.presentSuccessNotification(title, from: presenter, completion: nil)
            }
        }
    }
}

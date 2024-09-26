import UIKit

enum ExtrinsicSubmissionPresentingAction {
    case dismiss
    case dismissAllModals
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
        case .dismissAllModals:
            var root = view?.controller.view.window?.rootViewController

            root?.dismiss(animated: true) { [weak self] in
                self?.presentSuccessNotification(title, from: root, completion: nil)
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
            MainTransitionHelper.dismissAndPopBack(from: view) { [weak self] presenter in
                self?.presentSuccessNotification(title, from: presenter, completion: nil)
            }
        }
    }
}

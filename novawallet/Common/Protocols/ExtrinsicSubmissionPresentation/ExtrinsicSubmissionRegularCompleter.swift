import Foundation

final class ExtrinsicSubmissionRegularCompleter {}

extension ExtrinsicSubmissionRegularCompleter: ExtrinsicSubmissionCompliting {
    func handleCompletion(
        from view: ControllerBackedProtocol?,
        alertPresenting: ModalAlertPresenting,
        sender _: ExtrinsicSenderResolution?,
        completionAction: ExtrinsicSubmissionPresentingAction,
        locale: Locale
    ) -> Bool {
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: locale.rLanguages)

        switch completionAction {
        case .dismiss:
            let presenter = view?.controller.navigationController?.presentingViewController

            // TODO: Check strong capture here
            presenter?.dismiss(animated: true) {
                alertPresenting.presentSuccessNotification(title, from: presenter, completion: nil)
            }
        case .dismissAllModals:
            let root = view?.controller.view.window?.rootViewController

            root?.dismiss(animated: true) {
                alertPresenting.presentSuccessNotification(title, from: root, completion: nil)
            }
        case .pop:
            let presenter = view?.controller.navigationController
            view?.controller.navigationController?.popToRootViewController(animated: true)

            alertPresenting.presentSuccessNotification(title, from: presenter, completion: nil)
        case .popBack:
            let presenter = view?.controller.navigationController
            view?.controller.navigationController?.popViewController(animated: true)

            alertPresenting.presentSuccessNotification(title, from: presenter, completion: nil)
        case .popBaseAndDismiss:
            MainTransitionHelper.dismissAndPopBack(from: view) { presenter in
                alertPresenting.presentSuccessNotification(title, from: presenter, completion: nil)
            }
        }

        return true
    }
}

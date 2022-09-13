import Foundation

final class ParaStkYieldBoostScheduleConfirmWireframe: ParaStkYieldBoostScheduleConfirmWireframeProtocol,
    ModalAlertPresenting {
    func complete(on view: ParaStkYieldBoostScheduleConfirmViewProtocol?, locale: Locale) {
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: locale.rLanguages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) { [weak self] in
            self?.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}

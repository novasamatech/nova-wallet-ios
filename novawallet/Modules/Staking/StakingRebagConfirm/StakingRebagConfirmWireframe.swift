import Foundation

final class StakingRebagConfirmWireframe: StakingRebagConfirmWireframeProtocol, ModalAlertPresenting {
    func complete(from view: StakingRebagConfirmViewProtocol?, locale: Locale) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.stakingRebagConfirmCompletion()

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}

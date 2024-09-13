import Foundation

final class TinderGovSetupWireframe: TinderGovSetupWireframeProtocol {
    func showTinderGov(
        from view: ControllerBackedProtocol?,
        locale: Locale
    ) {
        let successAlertTitle = R.string.localizable.govVotingPowerSetSuccessMessage(
            preferredLanguages: locale.rLanguages
        )

        let navigationController = view?.controller.navigationController
        let presentingController = navigationController?.presentingViewController

        navigationController?.dismiss(animated: true)

        presentSuccessNotification(
            successAlertTitle,
            from: presentingController as? ControllerBackedProtocol
        )
    }
}

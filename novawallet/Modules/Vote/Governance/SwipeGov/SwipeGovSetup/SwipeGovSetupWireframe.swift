import Foundation

final class SwipeGovSetupWireframe: SwipeGovSetupWireframeProtocol {
    let newVotingPowerClosure: VotingPowerLocalSetClosure?

    init(newVotingPowerClosure: VotingPowerLocalSetClosure?) {
        self.newVotingPowerClosure = newVotingPowerClosure
    }

    func showSwipeGov(
        from view: ControllerBackedProtocol?,
        newVotingPower: VotingPowerLocal,
        locale: Locale
    ) {
        let successAlertTitle = R.string(preferredLanguages: locale.rLanguages).localizable.govVotingPowerSetSuccessMessage()

        let navigationController = view?.controller.navigationController
        let presentingController = navigationController?.presentingViewController

        navigationController?.dismiss(animated: true, completion: {
            self.newVotingPowerClosure?(newVotingPower)
        })

        presentSuccessNotification(
            successAlertTitle,
            from: presentingController as? ControllerBackedProtocol
        )
    }
}

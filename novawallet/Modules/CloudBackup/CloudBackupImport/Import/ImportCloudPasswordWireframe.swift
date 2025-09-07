import Foundation

final class ImportCloudPasswordWireframe: ImportCloudPasswordWireframeProtocol, ModalAlertPresenting {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func proceedAfterImport(
        from _: ImportCloudPasswordViewProtocol?,
        password _: String,
        locale _: Locale
    ) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: pincodeViewController)
    }

    func proceedAfterDelete(from view: ImportCloudPasswordViewProtocol?, locale: Locale) {
        let navigationController = view?.controller.navigationController
        navigationController?.popViewController(animated: true)

        presentMultilineSuccessNotification(
            R.string(preferredLanguages: locale.rLanguages
            ).localizable.cloudBackupDeleted(),
            from: view
        )
    }
}

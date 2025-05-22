import Foundation

final class WalletMigrateAcceptWhenOnboardWireframe: WalletMigrateAcceptWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func completeMigration(on view: WalletMigrateAcceptViewProtocol?) {
        view?.controller.dismiss(animated: true) {
            guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
                return
            }

            self.rootAnimator.animateTransition(to: pincodeViewController)
        }
    }
}

final class WalletMigrateAcceptWhenAddWireframe: WalletMigrateAcceptWireframeProtocol {
    func completeMigration(on view: WalletMigrateAcceptViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}

import Foundation

final class WalletMigrateAcceptWireframe: WalletMigrateAcceptWireframeProtocol {
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

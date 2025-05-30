import Foundation
import UIKit_iOS

final class WalletMigrateAcceptWhenOnboardWireframe: WalletMigrateAcceptWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func completeMigration(
        on view: WalletMigrateAcceptViewProtocol?,
        locale: Locale
    ) {
        let successAlertClosure = createSuccessfulMigrationAlertClosure(locale: locale)

        view?.controller.dismiss(animated: true) {
            guard let pincodeViewController = PinViewFactory.createPinSetupView(
                initialFlowStatusPresentingClosure: successAlertClosure
            )?.controller else {
                return
            }

            self.rootAnimator.animateTransition(to: pincodeViewController)
        }
    }
}

final class WalletMigrateAcceptWhenAddWireframe: WalletMigrateAcceptWireframeProtocol {
    func completeMigration(
        on view: WalletMigrateAcceptViewProtocol?,
        locale: Locale
    ) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        let successAlertClosure = createSuccessfulMigrationAlertClosure(locale: locale)

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            flowStatusClosure: successAlertClosure,
            animated: true
        )
    }
}

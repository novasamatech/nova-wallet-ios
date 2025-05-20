import UIKit

final class OnboardingMainWireframe: OnboardingMainBaseWireframe, OnboardingMainWireframeProtocol {
    func showSignup(from view: OnboardingMainViewProtocol?) {
        guard let usernameSetup = UsernameSetupViewFactory.createViewForOnboarding() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(usernameSetup.controller, animated: true)
        }
    }

    func showAccountRestore(from view: OnboardingMainViewProtocol?) {
        guard let importView = WalletImportOptionsViewFactory.createViewForOnboarding() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(importView.controller, animated: true)
        }
    }

    func showAccountSecretImport(from view: OnboardingMainViewProtocol?, source: SecretSource) {
        guard
            let navigationController = view?.controller.navigationController,
            !hasPendingFlow(in: navigationController) else {
            return
        }

        presentAccountRestore(from: view, secretSource: source)
    }

    func showWalletMigration(from view: OnboardingMainViewProtocol?, message _: WalletMigrationMessage.Start) {
        guard
            let navigationController = view?.controller.navigationController,
            !hasPendingFlow(in: navigationController) else {
            return
        }

        // TODO: show migration view
    }

    private func hasPendingFlow(in navigationController: UINavigationController) -> Bool {
        navigationController.viewControllers.count > 1 ||
            navigationController.presentedViewController != nil
    }

    private func presentAccountRestore(from view: OnboardingMainViewProtocol?, secretSource: SecretSource) {
        guard let restorationController = AccountImportViewFactory.createViewForOnboarding(
            for: secretSource
        )?.controller else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(restorationController, animated: true)
        }
    }
}

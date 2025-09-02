import UIKit
import Foundation_iOS
import UIKit_iOS

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

    func showWalletMigration(from view: OnboardingMainViewProtocol?, message: WalletMigrationMessage.Start) {
        guard
            let navigationController = view?.controller.navigationController,
            !hasPendingFlow(in: navigationController) else {
            return
        }

        guard let migrateView = WalletMigrateAcceptViewFactory.createViewForOnboarding(from: message) else {
            return
        }

        let nextNavigationController = NovaNavigationController(rootViewController: migrateView.controller)
        nextNavigationController.barSettings = nextNavigationController.barSettings.bySettingCloseButton(false)

        nextNavigationController.modalPresentationStyle = .fullScreen
        nextNavigationController.modalTransitionStyle = .crossDissolve

        view?.controller.present(nextNavigationController, animated: false)
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

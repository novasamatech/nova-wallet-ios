import Foundation

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
        presentSecretTypeSelection(from: view) { [weak self] secretSource in
            self?.presentAccountRestore(from: view, secretSource: secretSource)
        }
    }

    func showKeystoreImport(from view: OnboardingMainViewProtocol?) {
        if
            let navigationController = view?.controller.navigationController,
            navigationController.viewControllers.count == 1,
            navigationController.presentedViewController == nil {
            presentAccountRestore(from: view, secretSource: .keystore)
        }
    }

    private func presentAccountRestore(from view: OnboardingMainViewProtocol?, secretSource: SecretSource) {
        guard let restorationController = AccountImportViewFactory
            .createViewForOnboarding(for: secretSource)?.controller
        else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(restorationController, animated: true)
        }
    }
}

import Foundation

// @available(iOS, obsoleted: 10, message: "Network selection functionality does not longer exist")
extension SwitchAccount {
    final class OnboardingMainWireframe: OnboardingMainBaseWireframe, OnboardingMainWireframeProtocol {
        func showSignup(from view: OnboardingMainViewProtocol?) {
            guard let usernameSetup = UsernameSetupViewFactory.createViewForSwitch() else {
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
                navigationController.topViewController == view?.controller,
                navigationController.presentedViewController == nil {
                showAccountRestore(from: view)
            }
        }

        func showWatchOnlyCreate(from view: OnboardingMainViewProtocol?) {
            guard let watchOnlyView = CreateWatchOnlyViewFactory.createView() else {
                return
            }

            view?.controller.navigationController?.pushViewController(watchOnlyView.controller, animated: true)
        }

        private func presentAccountRestore(
            from view: OnboardingMainViewProtocol?,
            secretSource: SecretSource
        ) {
            guard let restorationController = AccountImportViewFactory.createViewForSwitch(
                for: secretSource
            )?.controller else {
                return
            }

            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(restorationController, animated: true)
            }
        }
    }
}

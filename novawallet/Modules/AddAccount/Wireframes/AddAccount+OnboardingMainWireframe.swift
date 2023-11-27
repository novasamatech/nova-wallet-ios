import Foundation

extension AddAccount {
    final class OnboardingMainWireframe: OnboardingMainBaseWireframe, OnboardingMainWireframeProtocol {
        func showSignup(from view: OnboardingMainViewProtocol?) {
            guard let usernameSetup = UsernameSetupViewFactory.createViewForAdding() else {
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

        func showAccountSecretImport(from view: OnboardingMainViewProtocol?, source: SecretSource) {
            if
                let navigationController = view?.controller.navigationController,
                navigationController.topViewController == view?.controller,
                navigationController.presentedViewController == nil {
                presentAccountRestore(from: view, secretSource: source)
            }
        }

        func showWatchOnlyCreate(from view: OnboardingMainViewProtocol?) {
            guard let watchOnlyView = CreateWatchOnlyViewFactory.createViewForAdding() else {
                return
            }

            view?.controller.navigationController?.pushViewController(watchOnlyView.controller, animated: true)
        }

        func showParitySignerWalletCreation(from view: OnboardingMainViewProtocol?, type: ParitySignerType) {
            guard
                let paritySignerWelcomeView = ParitySignerWelcomeViewFactory.createAddAccountView(
                    with: type
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                paritySignerWelcomeView.controller,
                animated: true
            )
        }

        func showLedgerWalletCreation(from view: OnboardingMainViewProtocol?) {
            guard let ledgerInstructions = LedgerInstructionsViewFactory.createView(for: .addWallet) else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                ledgerInstructions.controller,
                animated: true
            )
        }

        private func presentAccountRestore(
            from view: OnboardingMainViewProtocol?,
            secretSource: SecretSource
        ) {
            guard let restorationController = AccountImportViewFactory
                .createViewForAdding(for: secretSource)?.controller
            else {
                return
            }

            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(restorationController, animated: true)
            }
        }
    }
}

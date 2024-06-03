import Foundation

final class OnboardingImportOptionsWireframe: WalletImportOptionsWireframe, OnboardingImportOptionsWireframeProtocol {
    func showCloudImport(from view: WalletImportOptionsViewProtocol?) {
        guard let cloudImportView = ImportCloudPasswordViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(cloudImportView.controller, animated: true)
    }

    func showWatchOnlyImport(from view: WalletImportOptionsViewProtocol?) {
        guard let watchOnlyView = CreateWatchOnlyViewFactory.createViewForOnboarding() else {
            return
        }

        view?.controller.navigationController?.pushViewController(watchOnlyView.controller, animated: true)
    }

    override func showParitySignerWalletCreation(from view: ControllerBackedProtocol?, type: ParitySignerType) {
        guard
            let paritySignerWelcomeView = ParitySignerWelcomeViewFactory.createOnboardingView(
                with: type
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            paritySignerWelcomeView.controller,
            animated: true
        )
    }

    override func showLedgerWalletCreation(from view: ControllerBackedProtocol?) {
        guard let ledgerInstructions = LedgerInstructionsViewFactory.createView(for: .onboarding) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            ledgerInstructions.controller,
            animated: true
        )
    }

    override func showWalletRestore(from view: WalletImportOptionsViewProtocol?, secretSource: SecretSource) {
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

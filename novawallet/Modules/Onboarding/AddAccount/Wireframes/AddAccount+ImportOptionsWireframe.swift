import Foundation

extension AddAccount {
    final class ImportOptionsWireframe: WalletImportOptionsWireframe, WalletImportOptionsWireframeProtocol {
        func showWatchOnlyImport(from view: WalletImportOptionsViewProtocol?) {
            guard let watchOnlyView = CreateWatchOnlyViewFactory.createViewForAdding() else {
                return
            }

            view?.controller.navigationController?.pushViewController(watchOnlyView.controller, animated: true)
        }

        override func showParitySignerWalletCreation(from view: ControllerBackedProtocol?, type: ParitySignerType) {
            guard
                let paritySignerWelcomeView = PVWelcomeViewFactory.createAddAccountView(
                    with: type
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                paritySignerWelcomeView.controller,
                animated: true
            )
        }

        override func showLedgerWalletCreation(from view: ControllerBackedProtocol?, appType: LedgerWalletType) {
            guard let ledgerInstructions = LedgerInstructionsViewFactory.createView(
                for: .addWallet,
                walletLedgerType: appType
            ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                ledgerInstructions.controller,
                animated: true
            )
        }

        override func showWalletRestore(from view: WalletImportOptionsViewProtocol?, secretSource: SecretSource) {
            guard let restorationController = AccountImportViewFactory.createViewForAdding(
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

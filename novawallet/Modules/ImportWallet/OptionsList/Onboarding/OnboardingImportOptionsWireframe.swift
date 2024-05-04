import Foundation

final class OnboardingImportOptionsWireframe: WalletImportOptionsWireframe, OnboardingImportOptionsWireframeProtocol {
    func showCloudImport(from view: WalletImportOptionsViewProtocol?) {
        guard let cloudImportView = ImportCloudPasswordViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(cloudImportView.controller, animated: true)
    }

    func showPassphraseImport(from view: WalletImportOptionsViewProtocol?) {
        showWalletRestore(from: view, secretSource: .mnemonic)
    }

    func showHardwareImport(from view: WalletImportOptionsViewProtocol?, locale: Locale) {
        showHardwareWalletSelection(from: view, locale: locale)
    }

    func showWatchOnlyImport(from view: WalletImportOptionsViewProtocol?) {
        guard let watchOnlyView = CreateWatchOnlyViewFactory.createViewForOnboarding() else {
            return
        }

        view?.controller.navigationController?.pushViewController(watchOnlyView.controller, animated: true)
    }

    func showSeedImport(from view: WalletImportOptionsViewProtocol?) {
        showWalletRestore(from: view, secretSource: .seed)
    }

    func showRestoreJsonImport(from view: WalletImportOptionsViewProtocol?) {
        showWalletRestore(from: view, secretSource: .keystore)
    }
}

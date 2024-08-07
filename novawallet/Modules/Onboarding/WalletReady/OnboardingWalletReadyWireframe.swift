import Foundation

final class OnboardingWalletReadyWireframe: OnboardingWalletReadyWireframeProtocol {
    func showCloudBackup(from view: OnboardingWalletReadyViewProtocol?, walletName: String) {
        guard let cloudBackupView = CloudBackupCreateViewFactory.createViewForNewBackup(from: walletName) else {
            return
        }

        view?.controller.navigationController?.pushViewController(cloudBackupView.controller, animated: true)
    }

    func showManualBackup(from view: OnboardingWalletReadyViewProtocol?, walletName: String) {
        guard let manualBackupView = AccountCreateViewFactory.createViewForOnboarding(
            walletName: walletName
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(manualBackupView.controller, animated: true)
    }

    func showRecoverBackup(from view: OnboardingWalletReadyViewProtocol?) {
        guard let cloudImportView = ImportCloudPasswordViewFactory.createImportView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            cloudImportView.controller,
            animated: true
        )
    }

    func showExistingBackup(from view: OnboardingWalletReadyViewProtocol?, recoverClosure: @escaping () -> Void) {
        guard let hintView = CloudBackupMessageSheetViewFactory.createBackupAlreadyExists(for: recoverClosure) else {
            return
        }

        view?.controller.present(hintView.controller, animated: true)
    }
}

import Foundation

final class OnboardingWalletReadyWireframe: OnboardingWalletReadyWireframeProtocol {
    func showCloudBackup(from view: OnboardingWalletReadyViewProtocol?, walletName: String) {
        guard let cloudBackupView = CloudBackupCreateViewFactory.createView(from: walletName) else {
            return
        }

        view?.controller.navigationController?.pushViewController(cloudBackupView.controller, animated: true)
    }

    func showManualBackup(from _: OnboardingWalletReadyViewProtocol?, walletName _: String) {
        // TODO: Implement in separate task
    }
}

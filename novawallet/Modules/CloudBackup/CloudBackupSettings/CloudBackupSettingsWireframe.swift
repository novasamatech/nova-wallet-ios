import Foundation

final class CloudBackupSettingsWireframe: CloudBackupSettingsWireframeProtocol {
    func showManualBackup(from view: CloudBackupSettingsViewProtocol?) {
        guard let manualBackupWalletListView = ManualBackupWalletListViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            manualBackupWalletListView.controller,
            animated: true
        )
    }
}

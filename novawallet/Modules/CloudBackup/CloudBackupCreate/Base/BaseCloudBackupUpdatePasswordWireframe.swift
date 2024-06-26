import Foundation

class BaseCloudBackupUpdatePasswordWireframe {
    func showPasswordHint(from view: CloudBackupCreateViewProtocol?) {
        guard let hintView = CloudBackupMessageSheetViewFactory.createBackupMessageSheet() else {
            return
        }

        view?.controller.present(hintView.controller, animated: true)
    }
}

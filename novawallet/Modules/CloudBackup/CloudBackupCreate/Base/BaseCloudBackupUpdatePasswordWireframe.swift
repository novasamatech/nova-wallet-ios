import Foundation

class BaseCloudBackupUpdatePasswordWireframe {
    func showPasswordHint(from view: CloudBackupCreateViewProtocol?) {
        guard let hintView = CloudBackupMessageSheetViewFactory.createBackupMessageSheet() else {
            return
        }

        view?.controller.present(hintView.controller, animated: true)
    }

    func proceed(
        from _: CloudBackupCreateViewProtocol?,
        locale _: Locale
    ) {
        fatalError("Must be overriden by subsclass")
    }

    func proceed(
        from _: CloudBackupCreateViewProtocol?,
        password _: String,
        locale _: Locale
    ) {
        fatalError("Must be overriden by subsclass")
    }
}

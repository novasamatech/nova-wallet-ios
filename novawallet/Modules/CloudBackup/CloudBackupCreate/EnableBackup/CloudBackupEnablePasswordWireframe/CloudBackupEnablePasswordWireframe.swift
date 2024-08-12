import Foundation

final class CloudBackupEnablePasswordWireframe: BaseCloudBackupUpdatePasswordWireframe,
    CloudBackupCreateWireframeProtocol, ModalAlertPresenting {
    override func proceed(
        from view: (any CloudBackupCreateViewProtocol)?,
        password: String,
        locale _: Locale
    ) {
        guard let passwordConfirmView = CloudBackupCreateViewFactory.createConfirmViewForEnableBackup(
            password: password
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            passwordConfirmView.controller,
            animated: true
        )
    }
}

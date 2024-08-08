import Foundation

final class CloudBackupUpdatePasswordWireframe: BaseCloudBackupUpdatePasswordWireframe,
    CloudBackupCreateWireframeProtocol, ModalAlertPresenting {
    private let oldPassword: String

    init(oldPassword: String) {
        self.oldPassword = oldPassword
    }

    override func proceed(
        from view: CloudBackupCreateViewProtocol?,
        password: String,
        locale _: Locale
    ) {
        guard let passwordConfirmView = CloudBackupCreateViewFactory.createConfirmViewForUpdatePassword(
            for: password,
            oldPassword: oldPassword
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            passwordConfirmView.controller,
            animated: true
        )
    }
}

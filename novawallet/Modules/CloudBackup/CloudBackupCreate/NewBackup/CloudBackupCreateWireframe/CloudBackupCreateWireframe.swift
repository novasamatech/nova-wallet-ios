import Foundation

final class CloudBackupCreateWireframe: BaseCloudBackupUpdatePasswordWireframe, CloudBackupCreateWireframeProtocol {
    private var walletName: String

    init(walletName: String) {
        self.walletName = walletName
    }

    override func proceed(
        from view: CloudBackupCreateViewProtocol?,
        password: String,
        locale _: Locale
    ) {
        guard let passwordConfirmView = CloudBackupCreateViewFactory.createConfirmViewForNewBackup(
            from: walletName,
            passwordToConfirm: password
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            passwordConfirmView.controller,
            animated: true
        )
    }
}

import Foundation

final class CloudBackupEnablePasswordConfirmWireframe: BaseCloudBackupUpdatePasswordWireframe,
    CloudBackupCreateWireframeProtocol, ModalAlertPresenting {
    override func proceed(
        from view: CloudBackupCreateViewProtocol?,
        locale: Locale
    ) {
        guard
            let navigationController = view?.controller.navigationController,
            let cloudBackupSettingsView = navigationController.viewControllers.first(
                where: { $0 is CloudBackupSettingsViewProtocol }
            ) else {
            return
        }

        navigationController.popToViewController(cloudBackupSettingsView, animated: true)

        presentMultilineSuccessNotification(
            R.string.localizable.cloudBackupCreatedSuccessfully(
                preferredLanguages: locale.rLanguages
            ),
            from: view
        )
    }
}

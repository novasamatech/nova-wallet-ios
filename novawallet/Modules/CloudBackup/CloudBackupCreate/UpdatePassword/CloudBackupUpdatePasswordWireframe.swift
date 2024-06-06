import Foundation

final class CloudBackupUpdatePasswordWireframe: BaseCloudBackupUpdatePasswordWireframe,
    CloudBackupCreateWireframeProtocol, ModalAlertPresenting {
    func proceed(from view: CloudBackupCreateViewProtocol?, locale: Locale) {
        guard
            let navigationController = view?.controller.navigationController,
            let cloudBackupSettingsView = navigationController.viewControllers.first(
                where: { $0 is CloudBackupSettingsViewProtocol }
            ) else {
            return
        }

        navigationController.popToViewController(cloudBackupSettingsView, animated: true)

        presentSuccessNotification(
            R.string.localizable.cloudBackupPasswordChanged(
                preferredLanguages: locale.rLanguages
            ),
            from: view
        )
    }
}

import Foundation

final class CloudBackupEnterPasswordCheckWireframe: ImportCloudPasswordWireframeProtocol, ModalAlertPresenting {
    func proceedAfterImport(
        from view: ImportCloudPasswordViewProtocol?,
        password: String,
        locale _: Locale
    ) {
        guard let updatePasswordView = CloudBackupCreateViewFactory.createViewForUpdatePassword(
            for: password
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(updatePasswordView.controller, animated: true)
    }

    func proceedAfterDelete(from view: ImportCloudPasswordViewProtocol?, locale: Locale) {
        let navigationController = view?.controller.navigationController
        navigationController?.popViewController(animated: true)

        presentSuccessNotification(
            R.string.localizable.cloudBackupDeleted(
                preferredLanguages: locale.rLanguages
            ),
            from: view
        )
    }
}

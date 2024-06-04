import Foundation

final class CloudBackupEnterPasswordSetWireframe: ImportCloudPasswordWireframeProtocol, ModalAlertPresenting {
    func proceedAfterImport(
        from view: ImportCloudPasswordViewProtocol?,
        password _: String,
        locale: Locale
    ) {
        view?.controller.navigationController?.popViewController(animated: true)

        presentSuccessNotification(
            R.string.localizable.commonPasswordEnteredCorrectly(
                preferredLanguages: locale.rLanguages
            ),
            from: view
        )
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

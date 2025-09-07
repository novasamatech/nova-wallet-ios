import Foundation

final class CloudBackupEnterPasswordSetWireframe: ImportCloudPasswordWireframeProtocol, ModalAlertPresenting {
    func proceedAfterImport(
        from view: ImportCloudPasswordViewProtocol?,
        password _: String,
        locale: Locale
    ) {
        view?.controller.navigationController?.popViewController(animated: true)

        presentMultilineSuccessNotification(
            R.string(preferredLanguages: locale.rLanguages
            ).localizable.commonPasswordEnteredCorrectly(),
            from: view
        )
    }

    func proceedAfterDelete(from view: ImportCloudPasswordViewProtocol?, locale: Locale) {
        let navigationController = view?.controller.navigationController
        navigationController?.popViewController(animated: true)

        presentMultilineSuccessNotification(
            R.string(preferredLanguages: locale.rLanguages
            ).localizable.cloudBackupDeleted(),
            from: view
        )
    }
}

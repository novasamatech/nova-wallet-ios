import UIKit

protocol CloudBackupErrorPresentable {
    func presentCloudBackupUnavailable(from view: ControllerBackedProtocol, locale: Locale)
    func presentNotEnoughStorageForBackup(from view: ControllerBackedProtocol, locale: Locale)
    func presentNoCloudConnection(from view: ControllerBackedProtocol, locale: Locale)
    func presentBackupNotFound(from view: ControllerBackedProtocol, locale: Locale)
}

extension CloudBackupErrorPresentable where Self: AlertPresentable {
    private func presentOpenSettings(
        from view: ControllerBackedProtocol,
        title: String,
        message: String,
        locale: Locale
    ) {
        let settingsAction = AlertPresentableAction(
            title: R.string.localizable.commonOpenSettings(preferredLanguages: locale.rLanguages)
        ) {
            if
                let url = URL(string: UIApplication.openSettingsURLString),
                UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [settingsAction],
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages)
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentCloudBackupUnavailable(from view: ControllerBackedProtocol, locale: Locale) {
        let title = R.string.localizable.cloudBackupNotAvailableTitle(
            preferredLanguages: locale.rLanguages
        )

        let message = R.string.localizable.cloudBackupNotAvailableMessage(
            preferredLanguages: locale.rLanguages
        )

        presentOpenSettings(from: view, title: title, message: message, locale: locale)
    }

    func presentNotEnoughStorageForBackup(from view: ControllerBackedProtocol, locale: Locale) {
        let title = R.string.localizable.cloudBackupNotEnoughStorageTitle(
            preferredLanguages: locale.rLanguages
        )

        let message = R.string.localizable.cloudBackupNotEnoughStorageMessage(
            preferredLanguages: locale.rLanguages
        )

        presentOpenSettings(from: view, title: title, message: message, locale: locale)
    }

    func presentNoCloudConnection(from view: ControllerBackedProtocol, locale: Locale) {
        let title = R.string.localizable.connectionErrorTitle(
            preferredLanguages: locale.rLanguages
        )

        let message = R.string.localizable.connectionErrorMessage(
            preferredLanguages: locale.rLanguages
        )

        present(
            message: message,
            title: title,
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
            from: view
        )
    }

    func presentBackupNotFound(from view: ControllerBackedProtocol, locale: Locale) {
        let title = R.string.localizable.cloudBackupNotFoundTitle(
            preferredLanguages: locale.rLanguages
        )

        let message = R.string.localizable.cloudBackupNotFoundMessage(
            preferredLanguages: locale.rLanguages
        )

        present(
            message: message,
            title: title,
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
            from: view
        )
    }
}

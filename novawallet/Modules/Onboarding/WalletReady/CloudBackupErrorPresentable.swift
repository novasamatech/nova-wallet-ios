import UIKit

protocol CloudBackupErrorPresentable {
    func presentCloudBackupUnavailable(from view: ControllerBackedProtocol, locale: Locale)
    func presentNotEnoughStorageForBackup(from view: ControllerBackedProtocol, locale: Locale)
    func presentNoCloudConnection(from view: ControllerBackedProtocol, locale: Locale)
    func presentBackupNotFound(from view: ControllerBackedProtocol, locale: Locale)
    func presentInvalidBackupPassword(from view: ControllerBackedProtocol, locale: Locale)
}

extension CloudBackupErrorPresentable where Self: AlertPresentable {
    private func presentOpenSettings(
        from view: ControllerBackedProtocol,
        title: String,
        message: String,
        locale: Locale
    ) {
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentCloudBackupUnavailable(from view: ControllerBackedProtocol, locale: Locale) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupNotAvailableTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupNotAvailableMessage()

        presentOpenSettings(from: view, title: title, message: message, locale: locale)
    }

    func presentNotEnoughStorageForBackup(from view: ControllerBackedProtocol, locale: Locale) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupNotEnoughStorageTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupNotEnoughStorageMessage()

        presentOpenSettings(from: view, title: title, message: message, locale: locale)
    }

    func presentNoCloudConnection(from view: ControllerBackedProtocol, locale: Locale) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.connectionErrorTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.connectionErrorMessage()

        present(
            message: message,
            title: title,
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose(),
            from: view
        )
    }

    func presentBackupNotFound(from view: ControllerBackedProtocol, locale: Locale) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupNotFoundTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupNotFoundMessage()

        present(
            message: message,
            title: title,
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose(),
            from: view
        )
    }

    func presentInvalidBackupPassword(from view: ControllerBackedProtocol, locale: Locale) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonPasswordInvalidTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.commonPasswordInvalidMessage()

        present(
            message: message,
            title: title,
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose(),
            from: view
        )
    }
}

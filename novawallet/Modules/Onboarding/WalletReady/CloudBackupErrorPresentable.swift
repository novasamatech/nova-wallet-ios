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

    func presentInvalidBackupPassword(from view: ControllerBackedProtocol, locale: Locale) {
        let title = R.string.localizable.commonPasswordInvalidTitle(
            preferredLanguages: locale.rLanguages
        )

        let message = R.string.localizable.commonPasswordInvalidMessage(
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

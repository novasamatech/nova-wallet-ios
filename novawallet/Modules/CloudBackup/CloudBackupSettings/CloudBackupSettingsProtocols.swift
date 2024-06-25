import Foundation

protocol CloudBackupSettingsViewProtocol: ControllerBackedProtocol {
    var presenter: CloudBackupSettingsPresenterProtocol { get }

    func didReceive(viewModel: CloudBackupSettingsViewModel)
}

protocol CloudBackupSettingsPresenterProtocol: AnyObject {
    func setup()
    func toggleICloudBackup()
    func activateManualBackup()
    func activateSyncAction()
    func activateSyncIssue()

    func becomeActive()
    func becomeInactive()
}

protocol CloudBackupSettingsInteractorInputProtocol: AnyObject {
    func setup()
    func enableBackup()
    func disableBackup()
    func deleteBackup()
    func syncUp()
    func becomeActive()
    func becomeInactive()
    func approveBackupChanges()
    func fetchNumberOfWalletsWithSecrets()
}

protocol CloudBackupSettingsInteractorOutputProtocol: AnyObject {
    func didReceive(state: CloudBackupSyncState)
    func didReceive(error: CloudBackupSettingsInteractorError)
    func didReceive(numberOfWalletsWithSecrets: Int)
    func didDeleteBackup()
    func didReceive(syncMonitorStatus: CloudBackupSyncMonitorStatus?)
}

protocol CloudBackupSettingsWireframeProtocol: AlertPresentable, ErrorPresentable, CloudBackupErrorPresentable,
    ActionsManagePresentable, CloudBackupDeletePresentable, ModalAlertPresenting {
    func showManualBackup(from view: CloudBackupSettingsViewProtocol?)

    func showWalletsRemoveConfirmation(
        on view: CloudBackupSettingsViewProtocol?,
        locale: Locale,
        onConfirm: @escaping () -> Void
    )

    func showReviewUpdatesConfirmation(
        on view: CloudBackupSettingsViewProtocol?,
        locale: Locale,
        onConfirm: @escaping () -> Void
    )

    func showPasswordChangedConfirmation(
        on view: CloudBackupSettingsViewProtocol?,
        locale: Locale,
        onConfirm: @escaping () -> Void
    )

    func showCloudBackupReview(
        from view: CloudBackupSettingsViewProtocol?,
        changes: CloudBackupSyncResult.Changes,
        delegate: CloudBackupReviewChangesDelegate
    )

    func showEnterPassword(from view: CloudBackupSettingsViewProtocol?)

    func showChangePassword(from view: CloudBackupSettingsViewProtocol?)

    func showBackupCreation(from view: CloudBackupSettingsViewProtocol?)
}

enum CloudBackupSettingsInteractorError: Error {
    case deleteBackup(Error)
    case secretsCounter(Error)
}

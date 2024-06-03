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
    func checkSync()
}

protocol CloudBackupSettingsInteractorInputProtocol: AnyObject {
    func setup()
    func enableBackup()
    func disableBackup()
    func retryStateFetch()
    func checkBackupChangesConfirmationNeeded()
    func approveBackupChanges()
}

protocol CloudBackupSettingsInteractorOutputProtocol: AnyObject {
    func didReceive(state: CloudBackupSyncState)
    func didReceive(error: CloudBackupSettingsInteractorError)
    func didReceiveConfirmation(changes: CloudBackupSyncResult.Changes)
}

protocol CloudBackupSettingsWireframeProtocol: AlertPresentable, ErrorPresentable, CloudBackupErrorPresentable {
    func showManualBackup(from view: CloudBackupSettingsViewProtocol?)

    func showCloudBackupReview(
        from view: CloudBackupSettingsViewProtocol?,
        changes: CloudBackupSyncResult.Changes,
        delegate: CloudBackupReviewChangesDelegate
    )

    func showWalletsRemoveConfirmation(
        on view: CloudBackupSettingsViewProtocol?,
        locale: Locale,
        onConfirm: @escaping () -> Void
    )
}

enum CloudBackupSettingsInteractorError: Error {
    case enableBackup(Error)
    case disableBackup(Error)
}

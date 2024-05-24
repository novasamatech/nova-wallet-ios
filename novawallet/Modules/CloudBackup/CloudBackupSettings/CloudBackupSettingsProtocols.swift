protocol CloudBackupSettingsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: CloudBackupSettingsViewModel)
}

protocol CloudBackupSettingsPresenterProtocol: AnyObject {
    func setup()
    func toggleICloudBackup()
    func activateManualBackup()
    func activateSyncAction()
    func activateSyncIssue()
}

protocol CloudBackupSettingsInteractorInputProtocol: AnyObject {
    func setup()
    func enableBackup()
    func disableBackup()
    func retryStateFetch()
}

protocol CloudBackupSettingsInteractorOutputProtocol: AnyObject {
    func didReceive(state: CloudBackupSyncState)
    func didReceive(error: CloudBackupSettingsInteractorError)
}

protocol CloudBackupSettingsWireframeProtocol: AlertPresentable, ErrorPresentable, CloudBackupErrorPresentable {
    func showManualBackup(from view: CloudBackupSettingsViewProtocol?)
}

enum CloudBackupSettingsInteractorError: Error {
    case enableBackup(Error)
    case disableBackup(Error)
}

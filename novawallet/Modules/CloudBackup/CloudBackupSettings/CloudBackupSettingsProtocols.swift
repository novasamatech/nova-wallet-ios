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
    func apply(changes: CloudBackupSyncResult.Changes)
}

protocol CloudBackupSettingsInteractorOutputProtocol: AnyObject {
    func didReceive(state: CloudBackupSyncState)
}

protocol CloudBackupSettingsWireframeProtocol: AnyObject {
    func showManualBackup(from view: CloudBackupSettingsViewProtocol?)
}

protocol CloudBackupSettingsViewProtocol: ControllerBackedProtocol {}

protocol CloudBackupSettingsPresenterProtocol: AnyObject {
    func setup()
    func toggleICloudBackup()
    func activateManualBackup()
    func activateSyncAction()
    func activateSyncIssue()
}

protocol CloudBackupSettingsInteractorInputProtocol: AnyObject {}

protocol CloudBackupSettingsInteractorOutputProtocol: AnyObject {}

protocol CloudBackupSettingsWireframeProtocol: AnyObject {
    func showManualBackup(from view: CloudBackupSettingsViewProtocol?)
}

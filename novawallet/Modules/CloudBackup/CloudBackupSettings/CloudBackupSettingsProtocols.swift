protocol CloudBackupSettingsViewProtocol: ControllerBackedProtocol {}

protocol CloudBackupSettingsPresenterProtocol: AnyObject {
    func setup()
}

protocol CloudBackupSettingsInteractorInputProtocol: AnyObject {}

protocol CloudBackupSettingsInteractorOutputProtocol: AnyObject {}

protocol CloudBackupSettingsWireframeProtocol: AnyObject {}

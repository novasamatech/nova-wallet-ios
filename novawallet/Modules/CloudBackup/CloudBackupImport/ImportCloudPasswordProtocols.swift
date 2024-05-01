import SoraFoundation

protocol ImportCloudPasswordViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(passwordViewModel: InputViewModelProtocol)
}

protocol ImportCloudPasswordPresenterProtocol: AnyObject {
    func setup()
    func activateForgotPassword()
    func activateContinue()
}

protocol ImportCloudPasswordInteractorInputProtocol: AnyObject {
    func importBackup(for password: String)
    func deleteBackup()
}

protocol ImportCloudPasswordInteractorOutputProtocol: AnyObject {
    func didImportBackup()
    func didDeleteBackup()
    func didReceive(error: ImportCloudPasswordError)
}

protocol ImportCloudPasswordWireframeProtocol: ErrorPresentable, CloudBackupDeletePresentable {}

enum ImportCloudPasswordError: Error {}

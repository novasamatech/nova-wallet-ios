import SoraFoundation

protocol ImportCloudPasswordViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(passwordViewModel: InputViewModelProtocol)
}

protocol ImportCloudPasswordPresenterProtocol: AnyObject {
    func setup()
    func activateForgotPassword()
    func activateContinue()
}

protocol ImportCloudPasswordInteractorInputProtocol: AnyObject {}

protocol ImportCloudPasswordInteractorOutputProtocol: AnyObject {}

protocol ImportCloudPasswordWireframeProtocol: ErrorPresentable, CloudBackupDeletePresentable {}

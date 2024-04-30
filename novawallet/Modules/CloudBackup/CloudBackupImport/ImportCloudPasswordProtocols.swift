import SoraFoundation

protocol ImportCloudPasswordViewProtocol: ControllerBackedProtocol {
    func didReceive(passwordViewModel: InputViewModelProtocol)
}

protocol ImportCloudPasswordPresenterProtocol: AnyObject {
    func setup()
    func activateForgotPassword()
    func activateContinue()
}

protocol ImportCloudPasswordInteractorInputProtocol: AnyObject {}

protocol ImportCloudPasswordInteractorOutputProtocol: AnyObject {}

protocol ImportCloudPasswordWireframeProtocol: AnyObject {}

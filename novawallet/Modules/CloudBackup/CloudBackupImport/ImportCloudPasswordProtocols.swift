import SoraFoundation

protocol ImportCloudPasswordViewProtocol: AnyObject {
    func didReceive(passwordViewModel: InputViewModelProtocol)
}

protocol ImportCloudPasswordPresenterProtocol: AnyObject {
    func setup()
    func activateContinue()
}

protocol ImportCloudPasswordInteractorInputProtocol: AnyObject {}

protocol ImportCloudPasswordInteractorOutputProtocol: AnyObject {}

protocol ImportCloudPasswordWireframeProtocol: AnyObject {}

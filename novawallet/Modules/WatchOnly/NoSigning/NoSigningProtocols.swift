protocol NoSigningViewProtocol: ControllerBackedProtocol {}

protocol NoSigningPresenterProtocol: AnyObject {
    func goBack()
}

protocol NoSigningInteractorInputProtocol: AnyObject {}

protocol NoSigningInteractorOutputProtocol: AnyObject {}

protocol NoSigningWireframeProtocol: AnyObject {
    func complete(on view: NoSigningViewProtocol?)
}

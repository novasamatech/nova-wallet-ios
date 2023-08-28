protocol NPoolsUnstakeSetupViewProtocol: ControllerBackedProtocol {}

protocol NPoolsUnstakeSetupPresenterProtocol: AnyObject {
    func setup()
}

protocol NPoolsUnstakeSetupInteractorInputProtocol: NPoolsUnstakeBaseInteractorInputProtocol {}

protocol NPoolsUnstakeSetupInteractorOutputProtocol: NPoolsUnstakeBaseInteractorOutputProtocol {}

protocol NPoolsUnstakeSetupWireframeProtocol: NPoolsUnstakeBaseWireframeProtocol {}

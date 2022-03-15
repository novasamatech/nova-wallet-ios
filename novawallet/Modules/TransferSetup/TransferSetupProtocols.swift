protocol TransferSetupViewProtocol: ControllerBackedProtocol {}

protocol TransferSetupPresenterProtocol: AnyObject {
    func setup()
}

protocol TransferSetupInteractorInputProtocol: AnyObject {}

protocol TransferSetupInteractorOutputProtocol: AnyObject {}

protocol TransferSetupWireframeProtocol: AlertPresentable, ErrorPresentable {}

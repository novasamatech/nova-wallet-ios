protocol SwapConfirmViewProtocol: ControllerBackedProtocol {}

protocol SwapConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol SwapConfirmInteractorInputProtocol: SwapBaseInteractorInputProtocol {}

protocol SwapConfirmInteractorOutputProtocol: SwapBaseInteractorOutputProtocol {}

protocol SwapConfirmWireframeProtocol: AnyObject {}

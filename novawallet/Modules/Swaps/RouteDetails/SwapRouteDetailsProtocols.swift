protocol SwapRouteDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SwapRouteDetailsViewModel)
}

protocol SwapRouteDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol SwapRouteDetailsInteractorInputProtocol: AnyObject {}

protocol SwapRouteDetailsInteractorOutputProtocol: AnyObject {}

protocol SwapRouteDetailsWireframeProtocol: AnyObject {}

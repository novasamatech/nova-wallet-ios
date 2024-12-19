protocol SwapRouteDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SwapRouteDetailsViewModel)
}

protocol SwapRouteDetailsPresenterProtocol: AnyObject {
    func setup()
}

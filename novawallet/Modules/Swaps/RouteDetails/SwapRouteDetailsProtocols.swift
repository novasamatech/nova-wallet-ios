protocol SwapRouteDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SwapRouteDetailsViewModel)
    func didReceiveCommissionDisclosure(viewModel: String?)
}

protocol SwapRouteDetailsPresenterProtocol: AnyObject {
    func setup()
}

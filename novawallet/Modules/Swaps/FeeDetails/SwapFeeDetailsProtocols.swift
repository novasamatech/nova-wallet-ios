protocol SwapFeeDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SwapFeeDetailsViewModel)
}

protocol SwapFeeDetailsPresenterProtocol: AnyObject {
    func setup()
}

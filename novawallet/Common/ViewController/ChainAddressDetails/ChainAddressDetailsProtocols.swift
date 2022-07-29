protocol ChainAddressDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: ChainAddressDetailsViewModel)
}

protocol ChainAddressDetailsPresenterProtocol: AnyObject {
    func setup()
    func selectAction(at index: Int)
}

protocol ChainAddressDetailsWireframeProtocol: AnyObject {
    func close(view: ChainAddressDetailsViewProtocol?)
}

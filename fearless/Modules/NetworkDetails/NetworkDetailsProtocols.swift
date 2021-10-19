protocol NetworkDetailsViewProtocol: ControllerBackedProtocol {
    func reload(viewModel: NetworkDetailsViewModel)
}

protocol NetworkDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol NetworkDetailsViewModelFactoryProtocol {
    func createViewModel(chainModel: ChainModel) -> NetworkDetailsViewModel
}

protocol NetworkDetailsInteractorInputProtocol: AnyObject {}

protocol NetworkDetailsInteractorOutputProtocol: AnyObject {}

protocol NetworkDetailsWireframeProtocol: AnyObject {}

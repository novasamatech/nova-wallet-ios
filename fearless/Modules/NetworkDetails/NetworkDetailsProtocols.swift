import Foundation

protocol NetworkDetailsViewProtocol: ControllerBackedProtocol {
    func reload(viewModel: NetworkDetailsViewModel)
}

protocol NetworkDetailsPresenterProtocol: AnyObject {
    func setup()
    func handleActionButton()
}

protocol NetworkDetailsViewModelFactoryProtocol {
    func createViewModel(chainModel: ChainModel, locale: Locale) -> NetworkDetailsViewModel
}

protocol NetworkDetailsInteractorInputProtocol: AnyObject {}

protocol NetworkDetailsInteractorOutputProtocol: AnyObject {}

protocol NetworkDetailsWireframeProtocol: AnyObject {
    func showAddConnection(from view: ControllerBackedProtocol?)
}

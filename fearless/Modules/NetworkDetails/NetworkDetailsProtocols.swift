import Foundation

protocol NetworkDetailsViewProtocol: ControllerBackedProtocol {
    func reload(viewModel: NetworkDetailsViewModel)
}

protocol NetworkDetailsPresenterProtocol: AnyObject {
    func setup()
    func handleActionButton()
    func handleDefaultNodeInfo(at index: Int)
}

protocol NetworkDetailsViewModelFactoryProtocol {
    func createViewModel(chainModel: ChainModel, locale: Locale) -> NetworkDetailsViewModel
}

protocol NetworkDetailsInteractorInputProtocol: AnyObject {}

protocol NetworkDetailsInteractorOutputProtocol: AnyObject {}

protocol NetworkDetailsWireframeProtocol: AnyObject {
    func showAddConnection(from view: ControllerBackedProtocol?)
    func showNodeInfo(
        connectionItem: ConnectionItem,
        mode: NetworkInfoMode,
        from view: ControllerBackedProtocol?
    )
}

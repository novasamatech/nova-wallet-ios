import RobinHood
import IrohaCrypto

protocol NetworksViewProtocol: ControllerBackedProtocol {
    func reload(viewModel: NetworksViewModel)
}

protocol NetworksViewModelFactoryProtocol: AnyObject {
    func createViewModel(chains: [ChainModel], locale: Locale) -> NetworksViewModel
}

protocol NetworksPresenterProtocol: AnyObject {
    func setup()
    func handleChainSelection(id: String)
}

protocol NetworksInteractorInputProtocol: AnyObject {
    func setup()
}

protocol NetworksInteractorOutputProtocol: AnyObject {
    func didReceive(chainsResult: Result<[ChainModel]?, Error>)
}

protocol NetworksWireframeProtocol: AnyObject {
    func showNetworkDetails(chainModel: ChainModel, from view: ControllerBackedProtocol?)
}

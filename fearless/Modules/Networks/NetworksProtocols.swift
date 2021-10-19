import RobinHood
import IrohaCrypto

protocol NetworksViewProtocol: ControllerBackedProtocol {
    func reload(viewModel: NetworksViewModel)
}

protocol NetworksViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        chains: [ChainModel],
        chainSettings: Set<ChainSettingsModel>,
        locale: Locale
    ) -> NetworksViewModel
}

protocol NetworksPresenterProtocol: AnyObject {
    func setup()
}

protocol NetworksInteractorInputProtocol: AnyObject {
    func setup()
}

protocol NetworksInteractorOutputProtocol: AnyObject {
    func didReceive(chainsResult: Result<[ChainModel]?, Error>)
    func didReceive(chainSettingsResult: Result<ChainSettingsModel?, Error>)
}

protocol NetworksWireframeProtocol: ErrorPresentable, AlertPresentable {}

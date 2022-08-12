import RobinHood
import SoraFoundation

protocol ParitySignerAddressesViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModels: [ChainAccountViewModelItem])
}

protocol ParitySignerAddressesPresenterProtocol: AnyObject {
    func setup()
    func select(viewModel: ChainAccountViewModelItem)
    func proceed()
}

protocol ParitySignerAddressesInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ParitySignerAddressesInteractorOutputProtocol: AnyObject {
    func didReceive(accountId: AccountId)
    func didReceive(chains: [DataProviderChange<ChainModel>])
    func didReceive(error: Error)
}

protocol ParitySignerAddressesWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable {
    func showConfirmation(on view: ParitySignerAddressesViewProtocol?, accountId: AccountId)
}

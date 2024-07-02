import Foundation

protocol HardwareWalletAddressesViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [ChainAccountViewModelItem])
    func didReceive(descriptionViewModel: TitleWithSubtitleViewModel)
}

protocol HardwareWalletAddressesPresenterProtocol: AnyObject {
    func setup()
    func select(viewModel: ChainAccountViewModelItem)
    func proceed()
}

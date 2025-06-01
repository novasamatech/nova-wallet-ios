import Foundation

protocol HardwareWalletAddressesViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: HardwareWalletAddressesViewModel)
    func didReceive(descriptionViewModel: TitleWithSubtitleViewModel)
}

protocol HardwareWalletAddressesPresenterProtocol: AnyObject {
    func setup()
    func select(viewModel: ChainAccountViewModelItem)
    func proceed()
}

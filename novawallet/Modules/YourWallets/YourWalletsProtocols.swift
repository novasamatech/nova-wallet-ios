import UIKit

protocol YourWalletsViewProtocol: ControllerBackedProtocol {
    func update(viewModel: [YourWalletsViewSectionModel])
    func update(header: String)
}

protocol YourWalletsPresenterProtocol: AnyObject {
    func setup()
    func didSelect(viewModel: YourWalletsCellViewModel.CommonModel)
    func viewDidDisappear()
}

protocol YourWalletsDelegate: AnyObject {
    func didSelectYourWallet(address: AccountAddress)
    func didCloseYourWalletSelection()
}

extension YourWalletsDelegate {
    func didCloseYourWalletSelection() {}
}

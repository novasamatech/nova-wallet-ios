import UIKit

protocol YourWalletsViewProtocol: ControllerBackedProtocol {
    func update(viewModel: [YourWalletsViewSectionModel])
    func update(header: String)
}

protocol YourWalletsPresenterProtocol: AnyObject {
    func setup()
    func didSelect(viewModel: YourWalletsCellViewModel.CommonModel)
}

protocol YourWalletsDelegate: AnyObject {
    func selectWallet(address: AccountAddress)
}

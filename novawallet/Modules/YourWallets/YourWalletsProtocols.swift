import UIKit

protocol YourWalletsViewProtocol: ControllerBackedProtocol {
    func update(viewModel: [YourWalletsViewSectionModel])
}

protocol YourWalletsPresenterProtocol: AnyObject {
    func setup()
    func didSelect(viewModel: YourWalletsViewModelCell.CommonModel)
}

protocol YourWalletsDelegate: AnyObject {
    func selectWallet(address: AccountAddress)
}

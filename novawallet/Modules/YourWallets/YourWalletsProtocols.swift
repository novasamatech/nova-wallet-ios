import UIKit

protocol YourWalletsViewProtocol: ControllerBackedProtocol {
    func update(viewModel: [YourWalletsViewSectionModel])
    func update(header: String)
    func calculateEstimatedHeight(sections: Int, items: Int) -> CGFloat
}

protocol YourWalletsPresenterProtocol: AnyObject {
    func setup()
    func didSelect(viewModel: YourWalletsCellViewModel.CommonModel)
    func viewWillDisappear()
}

protocol YourWalletsDelegate: AnyObject {
    func didSelectYourWallet(address: AccountAddress)
    func didCloseYourWalletSelection()
}

extension YourWalletsDelegate {
    func didCloseYourWalletSelection() {}
}

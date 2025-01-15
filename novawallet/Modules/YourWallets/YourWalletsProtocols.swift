import UIKit

protocol YourWalletsPresentationProtocol: ControllerBackedProtocol {}

protocol YourWalletsViewProtocol: YourWalletsPresentationProtocol {
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
    func yourWallets(selectionView: YourWalletsPresentationProtocol, didSelect address: AccountAddress)
    func yourWalletsDidClose(selectionView: YourWalletsPresentationProtocol)
}

extension YourWalletsDelegate {
    func didCloseYourWalletSelection() {}
}

import UIKit
protocol YourWalletsViewProtocol: ControllerBackedProtocol {
    func update(viewModel: [YourWalletsViewModel])
}

protocol YourWalletsPresenterProtocol: AnyObject {
    func setup()
    func didSelect(viewModel: DisplayAddressViewModel)
}

protocol YourWalletsInteractorInputProtocol: AnyObject {}

protocol YourWalletsInteractorOutputProtocol: AnyObject {}

protocol YourWalletsWireframeProtocol: AnyObject {}

protocol YourWalletsDelegate: AnyObject {
    func selectWallet(address: AccountAddress?)
}

enum YourWalletsViewModel {
    case common(DisplayAddressViewModel, isSelected: Bool)
    case notFound(DisplayAddressViewModel)
}

import Foundation
import Foundation_iOS

protocol ChangeWatchOnlyViewProtocol: ControllerBackedProtocol {
    func didReceiveAddressState(viewModel: AccountFieldStateViewModel)
    func didReceiveAddressInput(viewModel: InputViewModelProtocol)
}

protocol ChangeWatchOnlyPresenterProtocol: AnyObject {
    func setup()
    func updateAddress(_ partialAddress: String)
    func performScan()
    func proceed()
}

protocol ChangeWatchOnlyInteractorInputProtocol: AnyObject {
    func save(address: AccountAddress)
}

protocol ChangeWatchOnlyInteractorOutputProtocol: AnyObject {
    func didSaveAddress(_ address: AccountAddress)
    func didReceiveError(_ error: Error)
}

protocol ChangeWatchOnlyWireframeProtocol: AlertPresentable, ErrorPresentable,
    BaseErrorPresentable, AddressScanPresentable {
    func complete(view: ChangeWatchOnlyViewProtocol?)
}

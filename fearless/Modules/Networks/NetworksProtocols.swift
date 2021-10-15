import RobinHood
import IrohaCrypto

protocol NetworksViewProtocol: ControllerBackedProtocol {
    func reload(state: NetworksViewState)
}

protocol NetworksPresenterProtocol: AnyObject {
    func setup()
}

protocol NetworksInteractorInputProtocol: AnyObject {
    func setup()
}

protocol NetworksInteractorOutputProtocol: AnyObject {}

protocol NetworksWireframeProtocol: ErrorPresentable, AlertPresentable {
//    func presentAccountSelection(
//        _ accounts: [AccountItem],
//        addressType: SNAddressType,
//        delegate: ModalPickerViewControllerDelegate,
//        from view: NetworkManagementViewProtocol?,
//        context: AnyObject?
//    )
//
//    func presentAccountCreation(
//        for connection: ConnectionItem,
//        from view: NetworkManagementViewProtocol?
//    )
//
//    func presentConnectionInfo(
//        _ connectionItem: ConnectionItem,
//        mode: NetworkInfoMode,
//        from view: NetworkManagementViewProtocol?
//    )
//
//    func presentConnectionAdd(from view: NetworkManagementViewProtocol?)
//
//    func complete(from view: NetworkManagementViewProtocol?)
}

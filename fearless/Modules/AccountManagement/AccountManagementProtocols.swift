import Foundation
import RobinHood
import SoraFoundation

// FIXME: Remove commented functions
protocol AccountManagementViewProtocol: ControllerBackedProtocol {
    func reload()

//    func didRemoveItem(at index: Int)
}

protocol AccountManagementPresenterProtocol: AnyObject {
    func setup()

    func numberOfSections() -> Int
    func numberOfItems(in section: Int) -> Int
    func item(at indexPath: IndexPath) -> ChainAccountViewModelItem
    func titleForSection(_ section: Int) -> LocalizableResource<String>

//    func activateDetails(at index: Int)
//    func activateAddAccount()
//
    func selectItem(at indexPath: IndexPath)
}

protocol AccountManagementInteractorInputProtocol: AnyObject {
    func setup()
//    func select(item: ManagedMetaAccountModel)
//    func save(items: [ManagedMetaAccountModel])
//    func remove(item: ManagedMetaAccountModel)
}

protocol AccountManagementInteractorOutputProtocol: AnyObject {
    func didReceiveChains(_ result: Result<[ChainModel.Id: ChainModel], Error>)
}

protocol AccountManagementWireframeProtocol: AlertPresentable, ErrorPresentable, WebPresentable, ModalAlertPresenting {
//    func showAccountDetails(from view: AccountManagementViewProtocol?, metaAccount: MetaAccountModel)
//    func showAddAccount(from view: AccountManagementViewProtocol?)
//    func complete(from view: AccountManagementViewProtocol?)
}

protocol AccountManagementViewFactoryProtocol: AnyObject {
    static func createView(for metaAccountModel: MetaAccountModel) -> AccountManagementViewProtocol?
//    static func createViewForSettings() -> AccountManagementViewProtocol?
//    static func createViewForSwitch() -> AccountManagementViewProtocol?
}

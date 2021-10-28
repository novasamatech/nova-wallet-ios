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
//    func selectItem(at index: Int)
//    func moveItem(at startIndex: Int, to finalIndex: Int)
//
//    func removeItem(at index: Int)
}

protocol AccountManagementInteractorInputProtocol: AnyObject {
    func setup()
//    func select(item: ManagedMetaAccountModel)
//    func save(items: [ManagedMetaAccountModel])
//    func remove(item: ManagedMetaAccountModel)
}

protocol AccountManagementInteractorOutputProtocol: AnyObject {
    func didReceiveChains()
//    func didCompleteSelection(of metaAccount: MetaAccountModel)
//    func didReceive(changes: [DataProviderChange<ManagedMetaAccountModel>])
//    func didReceive(error: Error)
}

protocol AccountManagementWireframeProtocol: AlertPresentable, ErrorPresentable {
//    func showAccountDetails(from view: AccountManagementViewProtocol?, metaAccount: MetaAccountModel)
//    func showAddAccount(from view: AccountManagementViewProtocol?)
//    func complete(from view: AccountManagementViewProtocol?)
}

protocol AccountManagementViewFactoryProtocol: AnyObject {
    static func createView(for metaAccountModel: MetaAccountModel) -> AccountManagementViewProtocol?
//    static func createViewForSettings() -> AccountManagementViewProtocol?
//    static func createViewForSwitch() -> AccountManagementViewProtocol?
}

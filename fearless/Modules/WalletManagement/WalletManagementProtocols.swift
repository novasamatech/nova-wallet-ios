import Foundation
import RobinHood

protocol WalletManagementViewProtocol: ControllerBackedProtocol {
    func reload()

    func didRemoveItem(at index: Int)
}

protocol WalletManagementPresenterProtocol: AnyObject {
    func setup()

    func numberOfItems() -> Int

    func item(at index: Int) -> ManagedWalletViewModelItem

    func activateDetails(at index: Int)
    func activateAddWallet()

    func selectItem(at index: Int)
    func moveItem(at startIndex: Int, to finalIndex: Int)

    func removeItem(at index: Int)
}

protocol WalletManagementInteractorInputProtocol: AnyObject {
    func setup()
    func select(item: ManagedMetaAccountModel)
    func save(items: [ManagedMetaAccountModel])
    func remove(item: ManagedMetaAccountModel)
}

protocol WalletManagementInteractorOutputProtocol: AnyObject {
    func didCompleteSelection(of metaAccount: MetaAccountModel)
    func didReceive(changes: [DataProviderChange<ManagedMetaAccountModel>])
    func didReceive(error: Error)
}

protocol WalletManagementWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showWalletDetails(from view: WalletManagementViewProtocol?, metaAccount: MetaAccountModel)
    func showAddWallet(from view: WalletManagementViewProtocol?)
    func complete(from view: WalletManagementViewProtocol?)
}

protocol WalletManagementViewFactoryProtocol: AnyObject {
    static func createViewForSettings() -> WalletManagementViewProtocol?
    static func createViewForSwitch() -> WalletManagementViewProtocol?
}

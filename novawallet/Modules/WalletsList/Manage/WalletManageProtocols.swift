import Foundation

protocol WalletManageViewProtocol: WalletsListViewProtocol {
    func didRemoveItem(at index: Int, section: Int)
}

protocol WalletManagePresenterProtocol: WalletsListPresenterProtocol {
    func selectItem(at index: Int, section: Int)
    func moveItem(at startIndex: Int, to finalIndex: Int, section: Int)
    func canDeleteItem(at index: Int, section: Int) -> Bool
    func removeItem(at index: Int, section: Int)
    func activateAddWallet()
}

protocol WalletManageInteractorInputProtocol: WalletsListInteractorInputProtocol {
    func save(items: [ManagedMetaAccountModel])
    func remove(item: ManagedMetaAccountModel)
}

protocol WalletManageInteractorOutputProtocol: WalletsListInteractorOutputProtocol {
    func didRemoveAllWallets()
    func didReceiveCloudBackup(state: CloudBackupSyncState)
}

protocol WalletManageWireframeProtocol: WalletsListWireframeProtocol, ActionsManagePresentable,
    CloudBackupRemindPresentable {
    func showWalletDetails(from view: WalletManageViewProtocol?, metaAccount: MetaAccountModel)
    func showCreateWalletWithManualBackup(from view: WalletManageViewProtocol?)
    func showCreateWalletWithCloudBackup(from view: WalletManageViewProtocol?)
    func showImportWallet(from view: WalletManageViewProtocol?)
    func showOnboarding(from view: WalletManageViewProtocol?)
}

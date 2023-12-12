import Foundation

protocol WalletSelectionPresenterProtocol: WalletsListPresenterProtocol {
    func selectItem(at index: Int, section: Int)
    func activateSettings()
}

protocol WalletSelectionInteractorInputProtocol: WalletsListInteractorInputProtocol {
    func select(item: ManagedMetaAccountModel)
    func updateWalletsStatuses()
}

protocol WalletSelectionInteractorOutputProtocol: WalletsListInteractorOutputProtocol {
    func didCompleteSelection()
    func didUpdateWallets()
}

protocol WalletSelectionWireframeProtocol: WalletsListWireframeProtocol {
    func close(view: WalletsListViewProtocol?)
    func showSettings(from view: WalletsListViewProtocol?)
    func showDelegateUpdates(
        from view: ControllerBackedProtocol?,
        initWallets: [ManagedMetaAccountModel],
        completion: @escaping () -> Void
    )
}

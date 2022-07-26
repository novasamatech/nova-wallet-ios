import Foundation

protocol WalletSelectionPresenterProtocol: WalletsListPresenterProtocol {
    func selectItem(at index: Int, section: Int)
    func activateSettings()
}

protocol WalletSelectionInteractorInputProtocol: WalletsListInteractorInputProtocol {
    func select(item: ManagedMetaAccountModel)
}

protocol WalletSelectionInteractorOutputProtocol: WalletsListInteractorOutputProtocol {
    func didCompleteSelection()
}

protocol WalletSelectionWireframeProtocol: WalletsListWireframeProtocol {
    func close(view: WalletsListViewProtocol?)
    func showSettings(from view: WalletsListViewProtocol?)
}

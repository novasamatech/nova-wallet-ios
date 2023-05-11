protocol WalletsChoosePresenterProtocol: WalletsListPresenterProtocol {
    func selectItem(at index: Int, section: Int)
}

protocol WalletsChooseDelegate: AnyObject {
    func walletChooseDidSelect(item: ManagedMetaAccountModel)
}

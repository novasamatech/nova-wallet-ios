protocol ManualBackupWalletListPresenterProtocol: WalletsListPresenterProtocol {
    func title() -> String
    func selectItem(at index: Int, section: Int)
}

protocol ManualBackupWalletListWireframeProtocol: WalletsListWireframeProtocol {
    func showBackupAttention(
        from view: WalletsListViewProtocol?,
        wallet: MetaAccountModel
    )
}

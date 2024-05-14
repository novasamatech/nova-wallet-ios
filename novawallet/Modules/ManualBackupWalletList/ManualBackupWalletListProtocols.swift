protocol ManualBackupWalletListPresenterProtocol: WalletsListPresenterProtocol {
    func selectItem(at index: Int, section: Int)
}

protocol ManualBackupWalletListWireframeProtocol: WalletsListWireframeProtocol {
    func showBackupAttention(
        from view: WalletsListViewProtocol?,
        wallet: MetaAccountModel
    )
}

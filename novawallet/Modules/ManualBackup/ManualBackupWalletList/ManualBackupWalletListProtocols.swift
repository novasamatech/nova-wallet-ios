protocol ManualBackupWalletListPresenterProtocol: WalletsListPresenterProtocol {
    func selectItem(at index: Int, section: Int)
}

protocol ManualBackupWalletListWireframeProtocol: WalletsListWireframeProtocol {
    func showBackupAttention(
        from view: WalletsListViewProtocol?,
        metaAccount: MetaAccountModel
    )

    func showChainAccountsList(
        from view: WalletsListViewProtocol?,
        metaAccount: MetaAccountModel
    )
}

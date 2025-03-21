import Operation_iOS

protocol ManualBackupKeyListViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: ManualBackupKeyListViewLayout.Model)
    func updateNavbar(with viewModel: DisplayWalletViewModel)
}

protocol ManualBackupKeyListPresenterProtocol: AnyObject {
    func setup()
    func activateDefaultKey()
    func activateCustomKey(with chainId: ChainModel.Id)
}

protocol ManualBackupKeyListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ManualBackupKeyListInteractorOutputProtocol: AnyObject {
    func didReceive(_ chainsChange: [DataProviderChange<ChainModel>])
}

protocol ManualBackupKeyListWireframeProtocol: AnyObject {
    func showDefaultAccountBackup(
        from view: ManualBackupKeyListViewProtocol?,
        with metaAccount: MetaAccountModel
    )
    func showCustomKeyAccountBackup(
        from view: ManualBackupKeyListViewProtocol?,
        with metaAccount: MetaAccountModel,
        chain: ChainModel
    )
}

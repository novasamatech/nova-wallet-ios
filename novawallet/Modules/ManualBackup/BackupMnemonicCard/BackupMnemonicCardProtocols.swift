import NovaCrypto

protocol BackupMnemonicCardViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: BackupMnemonicCardViewController.ViewModel)
}

protocol BackupMnemonicCardPresenterProtocol: AnyObject {
    func setup()
    func mnemonicCardTapped()
    func advancedTapped()
}

protocol BackupMnemonicCardInteractorInputProtocol: MnemonicFetchingInput {}

protocol BackupMnemonicCardInteractorOutputProtocol: MnemonicFetchingOutput {}

protocol BackupMnemonicCardWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showAdvancedExport(
        from view: BackupMnemonicCardViewProtocol?,
        with metaAccount: MetaAccountModel,
        chain: ChainModel?
    )
}

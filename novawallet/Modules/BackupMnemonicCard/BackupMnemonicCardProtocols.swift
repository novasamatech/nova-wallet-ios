import IrohaCrypto

protocol BackupMnemonicCardViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: BackupMnemonicCardViewController.ViewModel)
}

protocol BackupMnemonicCardPresenterProtocol: AnyObject {
    func setup()
    func mnemonicCardTapped()
    func advancedTapped()
}

protocol BackupMnemonicCardInteractorInputProtocol: AnyObject {
    func fetchMnemonic()
}

protocol BackupMnemonicCardInteractorOutputProtocol: AnyObject {
    func didReceive(mnemonic: IRMnemonicProtocol)
    func didReceive(error: Error)
}

protocol BackupMnemonicCardWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showAdvancedExport(from view: BackupMnemonicCardViewProtocol?)
}

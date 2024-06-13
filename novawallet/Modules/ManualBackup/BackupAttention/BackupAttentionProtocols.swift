protocol BackupAttentionViewProtocol: ControllerBackedProtocol, CheckboxListViewProtocol {}

protocol BackupAttentionPresenterProtocol: AnyObject {
    func setup()
}

protocol BackupAttentionInteractorInputProtocol: AnyObject {
    func checkIfMnemonicAvailable() -> Bool
}

protocol BackupAttentionWireframeProtocol: AnyObject {
    func showMnemonic(from view: BackupAttentionViewProtocol?)
    func showExportSecrets(from view: BackupAttentionViewProtocol?)
}

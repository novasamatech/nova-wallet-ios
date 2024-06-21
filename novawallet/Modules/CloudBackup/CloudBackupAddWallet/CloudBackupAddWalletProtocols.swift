protocol CloudBackupAddWalletInteractorInputProtocol: AnyObject {
    func createWallet(for name: String)
}

protocol CloudBackupAddWalletInteractorOutputProtocol: AnyObject {
    func didCreateWallet()
    func didReceive(error: CloudBackupAddWalletInteractorError)
}

protocol CloudBackupAddWalletWireframeProtocol: ErrorPresentable, AlertPresentable {
    func proceed(from view: UsernameSetupViewProtocol?)
}

enum CloudBackupAddWalletInteractorError: Error {
    case mnemonicGenerate(Error)
    case walletSave(Error)
}

import Foundation

protocol WalletImportOptionsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: WalletImportOptionViewModel)
}

protocol WalletImportOptionsPresenterProtocol: AnyObject {
    func setup()
}

protocol WalletImportOptionsWireframeProtocol {
    func showPassphraseImport(from view: WalletImportOptionsViewProtocol?)
    func showHardwareImport(from view: WalletImportOptionsViewProtocol?, locale: Locale)
    func showWatchOnlyImport(from view: WalletImportOptionsViewProtocol?)
    func showSeedImport(from view: WalletImportOptionsViewProtocol?)
    func showRestoreJsonImport(from view: WalletImportOptionsViewProtocol?)
    func showTrustWalletImport(from view: WalletImportOptionsViewProtocol?)
}

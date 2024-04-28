import Foundation

protocol OnboardingImportOptionsInteractorInputProtocol: AnyObject {
    func checkExistingBackup()
}

protocol OnboardingImportOptionsInteractorOutputProtocol: AnyObject {
    func didReceive(backupExists: Bool)
    func didReceive(error: OnboardingImportOptionsInteractorError)
}

protocol OnboardingImportOptionsWireframeProtocol: AlertPresentable, ErrorPresentable, CloudBackupErrorPresentable {
    func showCloudImport(from view: WalletImportOptionsViewProtocol?)
    func showPassphraseImport(from view: WalletImportOptionsViewProtocol?)
    func showHardwareImport(from view: WalletImportOptionsViewProtocol?, locale: Locale)
    func showWatchOnlyImport(from view: WalletImportOptionsViewProtocol?)
    func showSeedImport(from view: WalletImportOptionsViewProtocol?)
    func showRestoreJsonImport(from view: WalletImportOptionsViewProtocol?)
}

enum OnboardingImportOptionsInteractorError: Error {
    case cloudNotAvailable
    case serviceInternal(Error)
}

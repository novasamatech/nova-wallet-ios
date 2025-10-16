import Foundation

protocol OnboardingImportOptionsInteractorInputProtocol: AnyObject {
    func checkExistingBackup()
}

protocol OnboardingImportOptionsInteractorOutputProtocol: AnyObject {
    func didReceive(backupExists: Bool)
    func didReceive(error: OnboardingImportOptionsInteractorError)
}

protocol OnboardingImportOptionsWireframeProtocol: WalletImportOptionsWireframeProtocol, AlertPresentable,
    ErrorPresentable, CloudBackupErrorPresentable {
    func showCloudImport(from view: WalletImportOptionsViewProtocol?)
}

enum OnboardingImportOptionsInteractorError: Error {
    case cloudNotAvailable
    case serviceInternal(Error)
}

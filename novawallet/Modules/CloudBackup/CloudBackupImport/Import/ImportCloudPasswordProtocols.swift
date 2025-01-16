import Foundation_iOS

protocol ImportCloudPasswordViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(passwordViewModel: InputViewModelProtocol)
}

protocol ImportCloudPasswordPresenterProtocol: AnyObject {
    func setup()
    func activateForgotPassword()
    func activateContinue()
}

protocol ImportCloudPasswordInteractorInputProtocol: AnyObject {
    func importBackup(for password: String)
    func deleteBackup()
}

protocol ImportCloudPasswordInteractorOutputProtocol: AnyObject {
    func didImportBackup(with password: String)
    func didDeleteBackup()
    func didReceive(error: ImportCloudPasswordError)
}

protocol ImportCloudPasswordWireframeProtocol: ErrorPresentable, CloudBackupDeletePresentable,
    CloudBackupErrorPresentable {
    func proceedAfterImport(
        from view: ImportCloudPasswordViewProtocol?,
        password: String,
        locale: Locale
    )

    func proceedAfterDelete(from view: ImportCloudPasswordViewProtocol?, locale: Locale)
}

enum ImportCloudPasswordError: Error {
    case importInternal(Error)
    case backupBroken(Error)
    case emptyBackup
    case invalidPassword
    case deleteFailed(Error)
    case selectedWallet(Error?)
}

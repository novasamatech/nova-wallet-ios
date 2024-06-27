import Foundation

enum CloudBackupCreateInteractorError: Error {
    case alreadyInProgress
    case mnemonicCreation(Error)
    case walletCreation(Error)
    case backup(CloudBackupServiceFacadeError)
    case walletSave(Error)
}

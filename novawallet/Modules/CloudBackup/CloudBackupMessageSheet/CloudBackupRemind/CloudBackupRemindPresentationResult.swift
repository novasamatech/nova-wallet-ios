import Foundation

enum CloudBackupRemindPresentationResult {
    case present(view: MessageSheetViewProtocol)
    case confirmationNotNeeded
}

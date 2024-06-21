import Foundation

protocol CloudBackupRemindPresenterProtocol: MessageSheetPresenterProtocol {
    func proceed(skipInfoNextTime: Bool, action: MessageSheetAction?)
}

protocol CloudBackupRemindInteractorInputProtocol {
    func saveNoConfirmation(for completion: @escaping () -> Void)
}

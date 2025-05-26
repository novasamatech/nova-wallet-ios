import Foundation

protocol DelegatedMessageSheetPresenterProtocol: MessageSheetPresenterProtocol {
    func proceed(skipInfoNextTime: Bool, action: MessageSheetAction?)
}

protocol DelegatedMessageSheetInteractorInputProtocol {
    func saveNoConfirmation(for completion: @escaping () -> Void)
}

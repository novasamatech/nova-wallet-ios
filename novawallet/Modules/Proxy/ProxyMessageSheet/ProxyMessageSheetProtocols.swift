import Foundation

protocol ProxyMessageSheetPresenterProtocol: MessageSheetPresenterProtocol {
    func proceed(skipInfoNextTime: Bool, action: MessageSheetAction?)
}

protocol ProxyMessageSheetInteractorInputProtocol {
    func saveNoConfirmation(for completion: @escaping () -> Void)
}

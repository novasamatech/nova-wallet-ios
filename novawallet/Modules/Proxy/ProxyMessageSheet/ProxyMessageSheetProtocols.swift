import Foundation

protocol ProxyMessageSheetPresenterProtocol: MessageSheetPresenterProtocol {
    func proceed(skipInfoNextTime: Bool, action: MessageSheetAction?)
}

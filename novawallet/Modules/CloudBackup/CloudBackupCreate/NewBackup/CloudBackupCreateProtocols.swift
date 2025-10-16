import Foundation
import Foundation_iOS

protocol CloudBackupCreateViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(passwordViewModel: InputViewModelProtocol)
    func didRecieve(hints: [HintListView.ViewModel])
    func didReceive(canContinue: Bool)
}

protocol CloudBackupCreatePresenterProtocol: AnyObject {
    func setup()
    func applyEnterPasswordChange()
    func activateContinue()
    func activateOnAppear()
}

protocol CloudBackupCreateInteractorInputProtocol: AnyObject {
    func createWallet(for password: String)
}

protocol CloudBackupCreateInteractorOutputProtocol: AnyObject {
    func didCreateWallet()
    func didReceive(error: CloudBackupCreateInteractorError)
}

protocol CloudBackupCreateWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable,
    CloudBackupErrorPresentable {
    func proceed(
        from view: CloudBackupCreateViewProtocol?,
        locale: Locale
    )
    func proceed(
        from view: CloudBackupCreateViewProtocol?,
        password: String,
        locale: Locale
    )
    func showPasswordHint(from view: CloudBackupCreateViewProtocol?)
}

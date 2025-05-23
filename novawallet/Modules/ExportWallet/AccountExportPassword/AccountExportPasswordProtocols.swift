import Foundation
import Foundation_iOS

protocol AccountExportPasswordViewProtocol: ControllerBackedProtocol {
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol)
    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol)
}

protocol AccountExportPasswordPresenterProtocol: AnyObject {
    func setup()
    func proceed()
}

protocol AccountExportPasswordInteractorInputProtocol: AnyObject {
    func exportAccount(password: String)
}

protocol AccountExportPasswordInteractorOutputProtocol: AnyObject {
    func didExport(json: RestoreJson)
    func didReceive(error: Error)
}

protocol AccountExportPasswordWireframeProtocol: ErrorPresentable, AlertPresentable, SharingPresentable {
    func close(view: AccountExportPasswordViewProtocol?)
}

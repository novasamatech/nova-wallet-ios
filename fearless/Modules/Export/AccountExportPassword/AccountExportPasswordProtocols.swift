import Foundation
import SoraFoundation

protocol AccountExportPasswordViewProtocol: ControllerBackedProtocol {
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol)
    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol)
    func set(error: AccountExportPasswordError)
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

protocol AccountExportPasswordWireframeProtocol: ErrorPresentable, AlertPresentable {
    func showJSONExport(_ json: RestoreJson, from view: AccountExportPasswordViewProtocol?)
}

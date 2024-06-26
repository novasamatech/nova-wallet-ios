import Foundation

final class AccountExportPasswordWireframe: AccountExportPasswordWireframeProtocol {
    func close(view: AccountExportPasswordViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }
}

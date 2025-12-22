import Foundation

extension SwitchAccount {
    final class AccountImportWireframe: BaseAccountImportWireframe, AccountImportWireframeProtocol {
        func presentScanner(
            from view: AccountImportViewProtocol?,
            importDelegate: SecretScanImportDelegate
        ) {
            let scanView = SecretScanViewFactory.createView(importDelegate: importDelegate)

            view?.controller.navigationController?.pushViewController(
                scanView.controller,
                animated: true
            )
        }

        func proceed(from view: AccountImportViewProtocol?) {
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            navigationController.popToRootViewController(animated: true)
        }
    }
}

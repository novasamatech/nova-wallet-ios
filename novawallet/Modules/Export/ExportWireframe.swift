import Foundation

final class ExportWireframe: ExportWireframeProtocol {
    func showExportRestoreJSON(
        from view: ExportViewProtocol?,
        wallet: MetaAccountModel,
        chain: ChainModel?
    ) {
        guard
            let restorePasswordView = AccountExportPasswordViewFactory.createView(
                with: wallet,
                chain: chain
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            restorePasswordView.controller,
            animated: true
        )
    }
}

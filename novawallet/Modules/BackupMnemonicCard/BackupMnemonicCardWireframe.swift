import Foundation

final class BackupMnemonicCardWireframe: BackupMnemonicCardWireframeProtocol {
    func showAdvancedExport(
        from view: BackupMnemonicCardViewProtocol?,
        with metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) {
        guard let advancedExport = AdvancedExportViewFactory.createView(
            with: metaAccount,
            chain: chain
        ) else {
            return
        }

        view?.controller.present(advancedExport.controller, animated: true)
    }
}

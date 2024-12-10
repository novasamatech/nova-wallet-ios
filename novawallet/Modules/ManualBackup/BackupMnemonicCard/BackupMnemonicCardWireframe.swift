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

        let navigationController = NovaNavigationController(
            rootViewController: advancedExport.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }
}

import Foundation

final class BackupAttentionWireframe: BackupAttentionWireframeProtocol {
    private let metaAccount: MetaAccountModel
    private var chain: ChainModel?

    init(
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) {
        self.metaAccount = metaAccount
        self.chain = chain
    }

    func showMnemonic(from view: BackupAttentionViewProtocol?) {
        guard let backupMnemonicCardView = BackupMnemonicCardViewFactory.createView(
            with: metaAccount,
            chain: chain
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            backupMnemonicCardView.controller,
            animated: true
        )
    }

    func showExportSecrets(from view: BackupAttentionViewProtocol?) {
        guard let exportView = ExportViewFactory.createView(
            with: metaAccount,
            chain: chain
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            exportView.controller,
            animated: true
        )
    }
}

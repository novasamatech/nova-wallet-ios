import Foundation

final class BackupAttentionWireframe: BackupAttentionWireframeProtocol {
    private let metaAccount: MetaAccountModel

    init(metaAccount: MetaAccountModel) {
        self.metaAccount = metaAccount
    }

    func showMnemonic(from view: BackupAttentionViewProtocol?) {
        guard let backupMnemonicCardView = BackupMnemonicCardViewFactory.createView(with: metaAccount) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            backupMnemonicCardView.controller,
            animated: true
        )
    }
}

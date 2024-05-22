import Foundation

final class ManualBackupWalletListWireframe: ManualBackupWalletListWireframeProtocol, AuthorizationPresentable {
    func showBackupAttention(
        from view: WalletsListViewProtocol?,
        metaAccount: MetaAccountModel
    ) {
        guard let backupAttentionView = BackupAttentionViewFactory.createView(
            with: metaAccount,
            chain: .none
        ) else {
            return
        }

        authorize(animated: true, cancellable: true) { [weak self] completed in
            guard let self, completed else { return }

            view?.controller.navigationController?.pushViewController(
                backupAttentionView.controller,
                animated: true
            )
        }
    }

    func showChainAccountsList(
        from view: WalletsListViewProtocol?,
        metaAccount: MetaAccountModel
    ) {
        guard let backupAccountsList = ManualBackupKeyListViewFactory.createView(with: metaAccount) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            backupAccountsList.controller,
            animated: true
        )
    }
}

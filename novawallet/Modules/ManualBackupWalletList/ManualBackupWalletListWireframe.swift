import Foundation

final class ManualBackupWalletListWireframe: ManualBackupWalletListWireframeProtocol, AuthorizationPresentable {
    func showBackupAttention(
        from view: WalletsListViewProtocol?,
        wallet _: MetaAccountModel
    ) {
        guard let backupAttentionView = BackupAttentionViewFactory.createView() else {
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
}

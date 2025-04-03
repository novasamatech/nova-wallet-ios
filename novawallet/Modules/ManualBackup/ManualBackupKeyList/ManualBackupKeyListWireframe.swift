import Foundation
import UIKit_iOS

final class ManualBackupKeyListWireframe: ManualBackupKeyListWireframeProtocol, AuthorizationPresentable {
    func showDefaultAccountBackup(
        from view: ManualBackupKeyListViewProtocol?,
        with metaAccount: MetaAccountModel
    ) {
        showBackupAttentionScreen(
            from: view,
            with: metaAccount,
            chain: .none
        )
    }

    func showCustomKeyAccountBackup(
        from view: ManualBackupKeyListViewProtocol?,
        with metaAccount: MetaAccountModel,
        chain: ChainModel
    ) {
        showBackupAttentionScreen(
            from: view,
            with: metaAccount,
            chain: chain
        )
    }

    private func showBackupAttentionScreen(
        from view: ManualBackupKeyListViewProtocol?,
        with metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) {
        guard let backupAttentionView = BackupAttentionViewFactory.createView(
            with: metaAccount,
            chain: chain
        ) else {
            return
        }

        authorize(animated: true, cancellable: true) { completed in
            guard completed else { return }

            view?.controller.navigationController?.pushViewController(
                backupAttentionView.controller,
                animated: true
            )
        }
    }
}

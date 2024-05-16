import Foundation

final class BackupAttentionWireframe: BackupAttentionWireframeProtocol {
    func showMnemonic(from view: BackupAttentionViewProtocol?) {
        guard let backupMnemonicCardView = BackupMnemonicCardViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            backupMnemonicCardView.controller,
            animated: true
        )
    }
}

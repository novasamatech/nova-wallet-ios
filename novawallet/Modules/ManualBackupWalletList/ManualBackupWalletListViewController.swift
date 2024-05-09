import UIKit
import SoraFoundation

final class ManualBackupWalletListViewController: WalletsListViewController<
    ManualBackupWalletListViewLayout,
    WalletManageTableViewCell<SingleTitleWalletView>
> {
    var presenter: ManualBackupWalletListPresenterProtocol? {
        basePresenter as? ManualBackupWalletListPresenterProtocol
    }

    init(
        presenter: ManualBackupWalletListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        super.init(
            basePresenter: presenter,
            localizationManager: localizationManager
        )
    }

    // MARK: Table View Delegate

    override func tableView(_: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        UIView()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter?.selectItem(at: indexPath.row, section: indexPath.section)
    }
}

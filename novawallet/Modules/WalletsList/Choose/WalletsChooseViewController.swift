import UIKit
import Foundation_iOS

final class WalletsChooseViewController: WalletsListViewController<
    WalletsListViewLayout,
    WalletSelectionTableViewCell
> {
    var presenter: WalletsChoosePresenterProtocol? { basePresenter as? WalletsChoosePresenterProtocol }

    init(presenter: WalletsChoosePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        super.init(basePresenter: presenter, localizationManager: localizationManager)
    }

    override func setupLocalization() {
        title = R.string.localizable.commonSelectWallet(preferredLanguages: selectedLocale.rLanguages)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)

        presenter?.selectItem(at: indexPath.row, section: indexPath.section)
    }
}

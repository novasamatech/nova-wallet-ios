import UIKit
import Foundation_iOS

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

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
    }

    private func setupTableView() {
        rootView.tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)
    }

    // MARK: Table View Delegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let title = R.string.localizable.backupSelectWalletTitle(preferredLanguages: selectedLocale.rLanguages)
        let headerView: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.titleView.detailsLabel.apply(style: .boldTitle2Primary)
        headerView.titleView.bind(viewModel: .init(title: title, icon: nil))
        return headerView
    }

    override func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        UIConstants.headerHeight
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter?.selectItem(at: indexPath.row, section: indexPath.section)
    }
}

// MARK: Constants

private extension UIConstants {
    static let headerHeight: CGFloat = 28 + 16 + 8 // text box height + top padding + bottom padding
}

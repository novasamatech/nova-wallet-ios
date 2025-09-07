import UIKit
import Foundation
import Foundation_iOS

final class WalletManageViewController: WalletsListViewController<
    WalletManageViewLayout,
    WalletManageTableViewCell<WalletView>
> {
    var presenter: WalletManagePresenterProtocol? { basePresenter as? WalletManagePresenterProtocol }

    init(presenter: WalletManagePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        super.init(basePresenter: presenter, localizationManager: localizationManager)
    }

    override func viewDidLoad() {
        setupNavigationItem()
        setupHandlers()

        super.viewDidLoad()
    }

    override func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.profileWalletsTitle()

        rootView.addWalletButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.walletAddButtonTitle()

        rootView.addWalletButton.invalidateLayout()

        updateRightItem()
    }

    private func updateRightItem() {
        let languages = selectedLocale.rLanguages

        if rootView.tableView.isEditing {
            navigationItem.rightBarButtonItem?.title = R.string(preferredLanguages: languages
            ).localizable.commonDone()
        } else {
            navigationItem.rightBarButtonItem?.title = R.string(preferredLanguages: languages
            ).localizable.commonEdit()
        }
    }

    private func setupNavigationItem() {
        navigationItem.rightBarButtonItem = rootView.editButton
        rootView.editButton.target = self
        rootView.editButton.action = #selector(actionEdit)
    }

    private func setupHandlers() {
        rootView.addWalletButton.addTarget(self, action: #selector(actionAddWallet), for: .touchUpInside)
    }

    @objc private func actionAddWallet() {
        presenter?.activateAddWallet()
    }

    @objc private func actionEdit() {
        rootView.tableView.setEditing(!rootView.tableView.isEditing, animated: true)
        updateRightItem()

        for cell in rootView.tableView.visibleCells {
            if let walletCell = cell as? WalletManageTableViewCell<WalletView> {
                walletCell.setReordering(rootView.tableView.isEditing, animated: true)
            }
        }
    }

    // MARK: Table View Data Source

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        (cell as? WalletManageTableViewCell<WalletView>)?.setReordering(tableView.isEditing, animated: false)

        return cell
    }

    // MARK: Table View Delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter?.selectItem(at: indexPath.row, section: indexPath.section)
    }

    override func tableView(_: UITableView, canMoveRowAt _: IndexPath) -> Bool {
        true
    }

    override func tableView(
        _: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        presenter?.moveItem(
            at: sourceIndexPath.row,
            to: destinationIndexPath.row,
            section: destinationIndexPath.section
        )
    }

    override func tableView(
        _ tableView: UITableView,
        targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
        toProposedIndexPath proposedDestinationIndexPath: IndexPath
    ) -> IndexPath {
        if proposedDestinationIndexPath.section < sourceIndexPath.section {
            return IndexPath(row: 0, section: sourceIndexPath.section)
        } else if proposedDestinationIndexPath.section > sourceIndexPath.section {
            let count = tableView.numberOfRows(inSection: sourceIndexPath.section)
            return IndexPath(row: count - 1, section: sourceIndexPath.section)
        } else {
            return proposedDestinationIndexPath
        }
    }

    override func tableView(
        _: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        guard let presenter = presenter else {
            return .none
        }

        return presenter.canDeleteItem(at: indexPath.row, section: indexPath.section) ? .delete : .none
    }

    override func tableView(
        _: UITableView,
        commit _: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        presenter?.removeItem(at: indexPath.row, section: indexPath.section)
    }
}

extension WalletManageViewController: WalletManageViewProtocol {
    func didRemoveItem(at index: Int, section: Int) {
        let indexPath = IndexPath(row: index, section: section)
        rootView.tableView.deleteRows(at: [indexPath], with: .left)
    }
}

import UIKit
import SoraFoundation
import SoraUI

final class AccountManagementViewController: UIViewController {
    private enum Constants {
        static let cellHeight: CGFloat = 48.0
        static let addActionVerticalInset: CGFloat = 16
    }

    var presenter: AccountManagementPresenterProtocol!

    @IBOutlet private var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        title = R.string.localizable.walletChainManagementTitle(preferredLanguages: locale?.rLanguages)
    }

    private func setupTableView() {
//        tableView.tableFooterView = UIView()

        tableView.registerHeaderFooterView(
            withClass: ChainAccountListSectionView.self
        )

        tableView.register(R.nib.accountTableViewCell)
        tableView.rowHeight = Constants.cellHeight
    }
}

// swiftlint:disable force_cast
extension AccountManagementViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        presenter.numberOfSections()
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.numberOfItems(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: R.reuseIdentifier.accountCellId,
            for: indexPath
        )!

        cell.delegate = self

        let item = presenter.item(at: indexPath)
        cell.bind(viewModel: item)

        return cell
    }
}

// swiftlint:enable force_cast

extension AccountManagementViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: ChainAccountListSectionView = tableView.dequeueReusableHeaderFooterView()
        let title = presenter.titleForSection(section).value(for: selectedLocale)
        headerView.bind(description: title.uppercased())

        return headerView
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.selectItem(at: indexPath)
    }
}

extension AccountManagementViewController: AccountManagementViewProtocol {
    func reload() {
        tableView.reloadData()
    }
}

extension AccountManagementViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension AccountManagementViewController: AccountTableViewCellDelegate {
    func didSelectInfo(_ cell: AccountTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

//        presenter.activateDetails(at: indexPath.row)
    }
}

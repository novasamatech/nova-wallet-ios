import UIKit

final class ManualBackupKeyListViewController: UIViewController, ViewHolder {
    typealias RootViewType = ManualBackupKeyListViewLayout
    typealias CustomChainCell = PlainBaseTableViewCell<ChainAccountView>

    let presenter: ManualBackupKeyListPresenterProtocol

    private var viewModel: RootViewType.Model?

    init(presenter: ManualBackupKeyListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ManualBackupKeyListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        presenter.setup()
    }
}

// MARK: UITableViewDataSource & UITableViewDelegate

extension ManualBackupKeyListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel?.accountsSections.count ?? 0
    }

    func tableView(
        _: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        switch viewModel?.accountsSections[section] {
        case let .customKeys(sectionModel):
            return sectionModel.accounts.count
        case let .defaultKeys(sectionModel):
            return sectionModel.accounts.count
        default:
            return 0
        }
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let viewModel else { return UITableViewCell() }

        let cell: UITableViewCell

        switch viewModel.accountsSections[indexPath.section] {
        case let .defaultKeys(viewModel):
            let defaultChainsCell = tableView.dequeueReusableCellWithType(
                CustomChainCell.self,
                forIndexPath: indexPath
            )
            cell.contentDisplayView.networkIconView.image = R.image.iconNova()
            cell.contentDisplayView.networkLabel.text = viewModel.accounts[indexPath.row].title
            cell = defaultChainsCell
//            subtitle = viewModel.accounts[indexPath.row].subtitle
        case let .customKeys(viewModel):
            let customChainsCell = tableView.dequeueReusableCellWithType(
                CustomChainCell.self,
                forIndexPath: indexPath
            )
            viewModel.accounts[indexPath.row].network.icon?.loadImage(
                on: cell.contentDisplayView.networkIconView,
                targetSize: CGSize(width: 36, height: 36),
                animated: true
            )
            cell.contentDisplayView.networkLabel.text = viewModel.accounts[indexPath.row].network.name
            cell = customChainsCell
        }

        return cell
    }

    func tableView(
        _: UITableView,
        heightForRowAt _: IndexPath
    ) -> CGFloat {
        64
    }

    func tableView(
        _: UITableView,
        heightForHeaderInSection _: Int
    ) -> CGFloat {
        53
    }

    func tableView(
        _ tableView: UITableView,
        viewForHeaderInSection section: Int
    ) -> UIView? {
        let header: SettingsSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        let text = switch viewModel?.accountsSections[section] {
        case let .customKeys(sectionModel):
            sectionModel.headerText
        case let .defaultKeys(sectionModel):
            sectionModel.headerText
        default:
            String()
        }

        header.titleLabel.text = text

        return header
    }
}

// MARK: ManualBackupKeyListViewProtocol

extension ManualBackupKeyListViewController: ManualBackupKeyListViewProtocol {
    func update(with viewModel: ManualBackupKeyListViewLayout.Model) {
        self.viewModel = viewModel

        rootView.tableView.reloadData()
    }
}

// MARK: Private

private extension ManualBackupKeyListViewController {
    func setup() {
        rootView.tableView.registerClassForCell(Cell.self)
        rootView.tableView.registerHeaderFooterView(withClass: SettingsSectionHeaderView.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }
}

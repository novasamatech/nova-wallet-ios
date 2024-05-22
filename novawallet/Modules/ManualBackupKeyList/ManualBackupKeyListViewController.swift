import UIKit

final class ManualBackupKeyListViewController: UIViewController, ViewHolder {
    typealias RootViewType = ManualBackupKeyListViewLayout
    typealias CustomChainCell = CustomChainTableViewCell

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
            cell = UITableViewCell()
        case let .customKeys(viewModel):
            let customChainsCell = tableView.dequeueReusableCellWithType(
                CustomChainCell.self,
                forIndexPath: indexPath
            )
            customChainsCell.bind(with: viewModel.accounts[indexPath.row].network)
            cell = customChainsCell
        }

        cell.selectionStyle = .none

        return cell
    }

    func tableView(
        _: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        guard let viewModel else { return 0 }

        return switch viewModel.accountsSections[indexPath.section] {
        case .defaultKeys:
            Constants.cellHeight
        case .customKeys:
            Constants.cellHeight + CustomChainCell.Constants.bottomOffsetForSpacing
        }
    }

    func tableView(
        _: UITableView,
        heightForHeaderInSection _: Int
    ) -> CGFloat {
        Constants.headerHeight
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

        header.horizontalOffset = 0
        header.titleLabel.apply(style: .semiboldCaps2Secondary)
        header.titleLabel.text = text

        return header
    }
}

// MARK: ManualBackupKeyListViewProtocol

extension ManualBackupKeyListViewController: ManualBackupKeyListViewProtocol {
    func update(with viewModel: ManualBackupKeyListViewLayout.Model) {
        self.viewModel = viewModel

        rootView.headerView.bind(topValue: viewModel.listHeaderText, bottomValue: nil)
        rootView.tableView.reloadData()
    }
}

// MARK: Private

private extension ManualBackupKeyListViewController {
    func setup() {
        rootView.tableView.registerClassForCell(CustomChainCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: SettingsSectionHeaderView.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }
}

// MARK: Constants

private extension ManualBackupKeyListViewController {
    enum Constants {
        static let cellHeight: CGFloat = 64
        static let headerHeight: CGFloat = 53
    }
}

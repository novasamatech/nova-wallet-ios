import UIKit

final class DAppSettingsViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppSettingsViewLayout

    let presenter: DAppSettingsPresenterProtocol

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, DAppGlobalSettingsViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, DAppGlobalSettingsViewModel>
    private lazy var dataSource = createDataSource()
    private var titleModel: String = ""

    var preferredHeight: CGFloat {
        RootViewType.Constants.headerHeight + RootViewType.Constants.rowHeight * 2
    }

    init(presenter: DAppSettingsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppSettingsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self
        presenter.setup()
    }

    private func createDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { tableView, indexPath, itemIdentifier -> UITableViewCell? in
            switch itemIdentifier {
            case let .desktopModel(model):
                let cell: DAppDesktopModeSettingsView =
                    tableView.dequeueReusableCellWithType(DAppDesktopModeSettingsView.self, forIndexPath: indexPath)

                cell.iconDetailsView.bind(viewModel: model.title)
                cell.switchView.isOn = model.isOn
                cell.delegate = self
                cell.selectionStyle = .none
                return cell
            }
        }
    }
}

extension DAppSettingsViewController: DAppSettingsViewProtocol {
    func update(title: String) {
        titleModel = title
    }

    func update(viewModels: [DAppGlobalSettingsViewModel]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension DAppSettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let headerView: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.titleView.detailsLabel.apply(style: .bottomSheetTitle)
        headerView.contentInsets = .init(top: 10, left: 0, bottom: 10, right: 0)
        headerView.titleView.bind(viewModel: .init(title: titleModel, icon: nil))
        return headerView
    }
}

extension DAppSettingsViewController: DAppDesktopModeSettingsViewDelegate {
    func didChangeDesktopMode(isOn: Bool) {
        presenter.changeDesktopMode(isOn: isOn)
    }
}

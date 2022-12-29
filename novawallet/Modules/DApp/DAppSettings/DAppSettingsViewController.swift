import UIKit

final class DAppSettingsViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppSettingsViewLayout

    let presenter: DAppSettingsPresenterProtocol

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, DAppSettingsViewModelRow>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, DAppSettingsViewModelRow>
    private lazy var dataSource = createDataSource()
    private var titleModel: String = ""

    var preferredHeight: CGFloat {
        196
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

    @objc private func didChangeDesktopMode(control: UISwitch) {
        presenter.changeDesktopMode(isOn: control.isOn)
    }

    private func createDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { tableView, indexPath, itemIdentifier -> UITableViewCell? in
            switch itemIdentifier {
            case let .favorite(model):
                let cell: DAppFavoriteSettingsView = tableView.dequeueReusableCellWithType(
                    DAppFavoriteSettingsView.self,
                    forIndexPath: indexPath
                )
                cell.iconDetailsView.bind(viewModel: model)
                return cell
            case let .desktopModel(model):
                let cell: DAppDesktopModeSettingsView =
                    tableView.dequeueReusableCellWithType(DAppDesktopModeSettingsView.self, forIndexPath: indexPath)

                cell.iconDetailsView.bind(viewModel: model.title)
                cell.switchView.isOn = model.isOn
                cell.switchView.addTarget(
                    self,
                    action: #selector(self.didChangeDesktopMode),
                    for: .valueChanged
                )
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

    func update(viewModels: [DAppSettingsViewModelRow]) {
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
        headerView.titleView.bind(viewModel: .init(title: titleModel, icon: nil))
        return headerView
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let viewModel = dataSource.itemIdentifier(for: indexPath)
        switch viewModel {
        case .favorite:
            presenter.presentFavorite()
        case .desktopModel, .none:
            break
        }
    }
}

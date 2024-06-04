import UIKit
import SoraFoundation

final class NetworksListViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworksListViewLayout
    typealias ViewModel = RootViewType.Model
    typealias DataSource = UITableViewDiffableDataSource<RootViewType.Section, RootViewType.Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<RootViewType.Section, RootViewType.Row>
    typealias ChainCell = NetworksListTableViewCell

    let presenter: NetworksListPresenterProtocol

    private var viewModel: ViewModel?
    private var networkViewModels: [RootViewType.NetworkWithConnectionModel] = []

    private lazy var dataSource = makeDataSource()

    init(
        presenter: NetworksListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NetworksListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        presenter.setup()
    }
}

// MARK: UITableViewDelegate

extension NetworksListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.selectChain(at: indexPath.row)
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = viewModel?.sections[indexPath.section] else { return .zero }

        if case .networks = section {
            return 56
        } else {
            return UITableView.automaticDimension
        }
    }
}

// MARK: NetworksListViewProtocol

extension NetworksListViewController: NetworksListViewProtocol {
    func update(with viewModel: NetworksListViewLayout.Model) {
        self.viewModel = viewModel

        var snapshot = Snapshot()

        viewModel.sections.forEach { section in
            snapshot.appendSections([section])

            switch section {
            case let .networks(rows), let .banner(rows):
                snapshot.appendItems(rows)

                networkViewModels = rows.compactMap { row in
                    guard case let .network(networkModel) = row else {
                        return nil
                    }

                    return networkModel
                }
            }
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func updateNetworks(with viewModel: NetworksListViewLayout.Model) {
        viewModel.sections
            .enumerated()
            .forEach { sectionIndex, section in
                guard case let .networks(rows) = section else {
                    return
                }

                rows.forEach { row in
                    guard case let .network(networkModel) = row else {
                        return
                    }

                    let indexPath = IndexPath(
                        row: networkModel.index,
                        section: sectionIndex
                    )

                    let cell = rootView.tableView.cellForRow(at: indexPath) as? NetworksListTableViewCell
                    cell?.contentDisplayView.bind(with: networkModel)
                    networkViewModels[indexPath.row] = networkModel
                }
            }
    }
}

// MARK: Private

private extension NetworksListViewController {
    func setup() {
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(ChainCell.self)

        setupActions()
        setupNetworkSwitchTitles()
        setupNavigationBarTitle()
    }

    func setupActions() {
        rootView.networkTypeSwitch.addTarget(
            self,
            action: #selector(actionSegmentChanged),
            for: .valueChanged
        )

        let rightBarButtonItem = UIBarButtonItem(
            title: "Add",
            style: .plain,
            target: self,
            action: #selector(actionAddNetwork)
        )

        rightBarButtonItem.setupDefaultTitleStyle(with: .regularSubheadline)

        navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    func setupNetworkSwitchTitles() {
        rootView.networkTypeSwitch.titles = [
            R.string.localizable.connectionManagementDefaultTitle(
                preferredLanguages: selectedLocale.rLanguages
            ),
            R.string.localizable.connectionManagementCustomTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
        ]
    }

    func setupNavigationBarTitle() {
        navigationItem.title = R.string.localizable.connectionManagementTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    func makeDataSource() -> DataSource {
        DataSource(tableView: rootView.tableView) { [weak self] tableView, indexPath, viewModel in
            guard let self else { return nil }

            let cell: UITableViewCell

            switch viewModel {
            case let .banner(banerViewModel):
                // TODO: Implement
                cell = UITableViewCell()
            case .network:
                let networkModel = networkViewModels[indexPath.row]

                let chainCell = tableView.dequeueReusableCellWithType(
                    ChainCell.self,
                    forIndexPath: indexPath
                )

                chainCell.contentDisplayView.bind(with: networkModel)
                cell = chainCell
            }

            cell.selectionStyle = .none

            return cell
        }
    }

    @objc private func actionSegmentChanged() {
        presenter.select(
            segment: .init(rawValue: rootView.networkTypeSwitch.selectedSegmentIndex)
        )
    }

    @objc private func actionAddNetwork() {}

    func setupLocalization() {
        setupNetworkSwitchTitles()
        setupNavigationBarTitle()
    }
}

// MARK: Localizable

extension NetworksListViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}

// MARK: Constants

private extension NetworksListViewController {
    enum Constants {
        static let cellHeight: CGFloat = 64
        static let headerHeight: CGFloat = 53
        static let walletIconSize: CGSize = .init(
            width: 28,
            height: 28
        )
    }
}

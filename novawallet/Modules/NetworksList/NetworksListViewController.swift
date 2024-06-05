import UIKit
import SoraFoundation

final class NetworksListViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworksListViewLayout
    typealias ViewModel = RootViewType.Model
    typealias DataSource = UITableViewDiffableDataSource<RootViewType.Section, RootViewType.Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<RootViewType.Section, RootViewType.Row>
    typealias ChainCell = NetworksListTableViewCell
    typealias PlaceholderCell = NetworksEmptyTableViewCell
    typealias BannerCell = IntegrateNetworkBannerTableViewCell

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

        if case let .networks(rows) = section, case .network = rows[indexPath.row] {
            return 56
        } else {
            return UITableView.automaticDimension
        }
    }
}

// MARK: NetworksListViewProtocol

extension NetworksListViewController: NetworksListViewProtocol {
    func update(
        with viewModel: NetworksListViewLayout.Model,
        animated: Bool
    ) {
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

        dataSource.apply(snapshot, animatingDifferences: animated)
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

// MARK: NetworksEmptyPlaceholderViewDelegate

extension NetworksListViewController: NetworksEmptyPlaceholderViewDelegate {
    func didTapAddNetwork() {
        actionAddNetwork()
    }
}

// MARK: IntegrateNetworksBannerDekegate

extension NetworksListViewController: IntegrateNetworksBannerDekegate {
    func didTapClose() {
        presenter.closeBanner()
    }
}

// MARK: Private

private extension NetworksListViewController {
    func setup() {
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(ChainCell.self)
        rootView.tableView.registerClassForCell(PlaceholderCell.self)
        rootView.tableView.registerClassForCell(BannerCell.self)

        dataSource.defaultRowAnimation = .fade

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
            title: R.string.localizable.networksListAddNetworkButtonTitle(
                preferredLanguages: selectedLocale.rLanguages
            ),
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
            guard let self else { return UITableViewCell() }

            let cell: UITableViewCell

            switch viewModel {
            case let .banner:
                let bannerCell = tableView.dequeueReusableCellWithType(
                    BannerCell.self,
                    forIndexPath: indexPath
                )

                bannerCell.contentDisplayView.set(locale: selectedLocale)
                bannerCell.contentDisplayView.delegate = self

                cell = bannerCell
            case let .placeholder(placeholderViewModel):
                let placeholderCell = tableView.dequeueReusableCellWithType(
                    PlaceholderCell.self,
                    forIndexPath: indexPath
                )

                placeholderCell.contentDisplayView.bind(with: placeholderViewModel)
                placeholderCell.contentDisplayView.delegate = self
                cell = placeholderCell
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

    @objc private func actionAddNetwork() {
        presenter.addNetwork()
    }

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

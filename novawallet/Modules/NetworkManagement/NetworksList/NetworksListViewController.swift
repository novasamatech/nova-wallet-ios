import UIKit
import SoraFoundation

final class NetworksListViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworksListViewLayout
    typealias ViewModel = RootViewType.Model
    typealias ChainCell = NetworksListTableViewCell
    typealias PlaceholderCell = NetworksEmptyTableViewCell
    typealias BannerCell = IntegrateNetworkBannerTableViewCell

    let presenter: NetworksListPresenterProtocol

    private var viewModel: ViewModel?
    private var networkViewModels: [RootViewType.NetworkWithConnectionModel] = []

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

// MARK: NetworksListViewProtocol

extension NetworksListViewController: NetworksListViewProtocol {
    func update(with viewModel: NetworksListViewLayout.Model) {
        self.viewModel = viewModel

        networkViewModels = extractNetworkViewModels(from: viewModel)

        rootView.tableView.reloadData()
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

// MARK: UITableViewDataSource

extension NetworksListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel?.sections.count ?? 0
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewModel?.sections[section] {
        case let .banner(rows), let .networks(rows):
            return rows.count
        case .none:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel else { return UITableViewCell() }

        return switch viewModel.sections[indexPath.section] {
        case let .banner(rows), let .networks(rows):
            cellFor(
                row: rows[indexPath.row],
                in: tableView,
                at: indexPath
            )
        }
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
            return Constants.cellHeight
        } else {
            return UITableView.automaticDimension
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
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(ChainCell.self)
        rootView.tableView.registerClassForCell(PlaceholderCell.self)
        rootView.tableView.registerClassForCell(BannerCell.self)

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

    func cellFor(
        row viewModel: NetworksListViewLayout.Row,
        in tableView: UITableView,
        at indexPath: IndexPath
    ) -> UITableViewCell {
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

    func extractNetworkViewModels(from viewModel: ViewModel) -> [RootViewType.NetworkWithConnectionModel] {
        viewModel.sections
            .compactMap { section -> [RootViewType.NetworkWithConnectionModel]? in
                guard case let .networks(rows) = section else { return nil }

                return rows.compactMap { row in
                    guard case let .network(networkModel) = row else {
                        return nil
                    }

                    return networkModel
                }
            }
            .flatMap { $0 }
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
        static let cellHeight: CGFloat = 56
    }
}
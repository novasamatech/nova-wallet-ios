import UIKit
import Foundation_iOS

final class NetworksListViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworksListViewLayout
    typealias ViewModel = RootViewType.Model
    typealias ChainCell = NetworksListTableViewCell
    typealias PlaceholderCell = NetworksEmptyTableViewCell
    typealias BannerCell = IntegrateNetworkBannerTableViewCell

    let presenter: NetworksListPresenterProtocol

    private var viewModel: ViewModel?
    private var networkViewModels: [RootViewType.NetworkWithConnectionModel] = []
    private var networkSectionIndex: Int? {
        viewModel?.sections.firstIndex(
            where: { section in
                if case .networks = section {
                    return true
                } else {
                    return false
                }
            }
        )
    }

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        rootView.tableView.reloadData()
        setupActions()
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
        guard let networkSectionIndex else { return }

        viewModel.sections
            .forEach { section in
                guard case let .networks(rows) = section else { return }

                rows.forEach { row in
                    guard case let .network(networkModel) = row else {
                        return
                    }

                    let indexPath = IndexPath(
                        row: networkModel.index,
                        section: networkSectionIndex
                    )

                    let cell = rootView.tableView.cellForRow(at: indexPath) as? ChainCell
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

    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        UIView()
    }

    func tableView(_: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        UIView()
    }
}

// MARK: UITableViewDelegate

extension NetworksListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard
            let section = viewModel?.sections[indexPath.section],
            case let .networks(rows) = section, case .network = rows[indexPath.row]
        else {
            return
        }

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

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        spacing(for: section)
    }

    func tableView(_: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        spacing(for: section)
    }
}

// MARK: NetworksEmptyPlaceholderViewDelegate

extension NetworksListViewController: NetworksEmptyPlaceholderViewDelegate {
    func didTapAddNetwork() {
        actionAddNetwork()
    }
}

// MARK: IntegrateNetworksBannerDekegate

extension NetworksListViewController: IntegrateNetworksBannerDelegate {
    func didTapClose() {
        presenter.closeBanner()
    }

    func didTapIntegrateNetwork() {
        presenter.integrateOwnNetwork()
    }
}

// MARK: UITextFieldDelegate

extension NetworksListViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
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

        setupLocalization()
    }

    func setupActions() {
        rootView.searchTextField.addTarget(
            self,
            action: #selector(actionSearchEditingChanged),
            for: .editingChanged
        )

        rootView.searchTextField.delegate = self

        rootView.networkTypeSwitch.addTarget(
            self,
            action: #selector(actionSegmentChanged),
            for: .valueChanged
        )

        let rightBarButtonItem = UIBarButtonItem(
            title: R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.networksListAddNetworkButtonTitle(),
            style: .plain,
            target: self,
            action: #selector(actionAddNetwork)
        )

        rightBarButtonItem.setupDefaultTitleStyle(with: .regularSubheadline)
        navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    func setupNetworkSwitchTitles() {
        rootView.networkTypeSwitch.titles = [
            R.string(preferredLanguages: selectedLocale.rLanguages).localizable.connectionManagementDefaultTitle(),
            R.string(preferredLanguages: selectedLocale.rLanguages).localizable.connectionManagementCustomTitle()
        ]
    }

    func setupNavigationBarTitle() {
        navigationItem.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.connectionManagementTitle()
    }

    func setupTextFieldPlaceholder() {
        rootView.searchTextField.placeholder = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.networkKnownListSearchPlaceholder()
    }

    @objc private func actionSegmentChanged() {
        presenter.select(
            segment: .init(rawValue: rootView.networkTypeSwitch.selectedSegmentIndex)
        )
    }

    @objc private func actionAddNetwork() {
        presenter.addNetwork()
    }

    @objc private func actionSearchEditingChanged() {
        let query = rootView.searchTextField.text ?? ""

        presenter.search(with: query)
    }

    func setupLocalization() {
        setupNetworkSwitchTitles()
        setupNavigationBarTitle()
        setupTextFieldPlaceholder()
    }

    func cellFor(
        row viewModel: NetworksListViewLayout.Row,
        in tableView: UITableView,
        at indexPath: IndexPath
    ) -> UITableViewCell {
        let cell: UITableViewCell

        switch viewModel {
        case .banner:
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

    func spacing(for sectionIndex: Int) -> CGFloat {
        guard
            let viewModel, viewModel.sections.count > sectionIndex,
            case .banner = viewModel.sections[sectionIndex]
        else { return .zero }

        return Constants.sectionSpacing
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
        static let sectionSpacing: CGFloat = 16
    }
}

import UIKit
import Foundation_iOS

final class KnownNetworksListViewController: UIViewController, ViewHolder {
    typealias RootViewType = KnownNetworksListViewLayout
    typealias ViewModel = RootViewType.Model
    typealias ChainCell = NetworksListTableViewCell
    typealias AddNetworkCell = AddNetworkManuallyTableViewCell

    let presenter: KnownNetworksListPresenterProtocol

    private var viewModel: ViewModel?

    init(
        presenter: KnownNetworksListPresenterProtocol,
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
        view = KnownNetworksListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        presenter.becameActive()
    }
}

// MARK: KnownNetworksListViewProtocol

extension KnownNetworksListViewController: KnownNetworksListViewProtocol {
    func update(with viewModel: KnownNetworksListViewLayout.Model) {
        self.viewModel = viewModel

        rootView.tableView.reloadData()
    }
}

// MARK: UITableViewDataSource

extension KnownNetworksListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel?.sections.count ?? 0
    }

    func tableView(
        _: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        switch viewModel?.sections[section] {
        case let .addNetwork(rows), let .networks(rows):
            return rows.count
        case .none:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel else { return UITableViewCell() }

        return switch viewModel.sections[indexPath.section] {
        case let .addNetwork(rows), let .networks(rows):
            cellFor(
                row: rows[indexPath.row],
                in: tableView,
                at: indexPath
            )
        }
    }
}

// MARK: UITableViewDelegate

extension KnownNetworksListViewController: UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case Constants.addNetworksSection:
            presenter.addNetworkManually()
        case Constants.networksSection:
            presenter.selectChain(at: indexPath.row)
        default:
            break
        }
    }

    func tableView(
        _: UITableView,
        heightForRowAt _: IndexPath
    ) -> CGFloat {
        56
    }
}

// MARK: Private

private extension KnownNetworksListViewController {
    func setup() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(ChainCell.self)
        rootView.tableView.registerClassForCell(AddNetworkCell.self)

        setupSearchField()
        setupLocalization()
    }

    private func setupSearchField() {
        rootView.searchTextField.addTarget(
            self,
            action: #selector(actionSearchEditingChanged),
            for: .editingChanged
        )

        rootView.searchTextField.delegate = self
    }

    func setupLocalization() {
        navigationItem.title = R.string.localizable.networksListAddNetworkButtonTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.searchTextField.placeholder = R.string.localizable.networkKnownListSearchPlaceholder(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    func cellFor(
        row viewModel: KnownNetworksListViewLayout.Row,
        in tableView: UITableView,
        at indexPath: IndexPath
    ) -> UITableViewCell {
        let cell: UITableViewCell

        switch viewModel {
        case let .addNetwork(viewModel):
            let addNetworkCell = tableView.dequeueReusableCellWithType(
                AddNetworkCell.self,
                forIndexPath: indexPath
            )
            addNetworkCell.bind(model: viewModel)

            cell = addNetworkCell
        case let .network(model):
            let chainCell = tableView.dequeueReusableCellWithType(
                ChainCell.self,
                forIndexPath: indexPath
            )

            chainCell.contentDisplayView.bind(with: model)
            cell = chainCell
        }

        cell.selectionStyle = .none

        return cell
    }

    @objc private func actionSearchEditingChanged() {
        let query = rootView.searchTextField.text ?? ""

        presenter.search(by: query)
    }
}

// MARK: UITextFieldDelegate

extension KnownNetworksListViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// MARK: Localizable

extension KnownNetworksListViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}

// MARK: Constants

private extension KnownNetworksListViewController {
    enum Constants {
        static let cellHeight: CGFloat = 56
        static let addNetworksSection: Int = 0
        static let networksSection: Int = 1
    }
}

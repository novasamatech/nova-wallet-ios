import UIKit
import SoraFoundation

final class KnownNetworksListViewController: UIViewController, ViewHolder {
    typealias RootViewType = KnownNetworksListViewLayout
    typealias ViewModel = RootViewType.Model
    typealias ChainCell = NetworksListTableViewCell

    let presenter: KnownNetworksListPresenterProtocol
    
    private var viewModel: ViewModel?

    init(presenter: KnownNetworksListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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

        presenter.setup()
    }
}

extension KnownNetworksListViewController: KnownNetworksListViewProtocol {}

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
        presenter.selectChain(at: indexPath.row)
    }

    func tableView(
        _: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        return 56
    }
}

// MARK: Private

private extension KnownNetworksListViewController {
    func setup() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(ChainCell.self)

        setupNavigationBarTitle()
    }

    func setupNavigationBarTitle() {
        navigationItem.title = R.string.localizable.networksListAddNetworkButtonTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    func setupLocalization() {
        setupNavigationBarTitle()
    }

    func cellFor(
        row viewModel: KnownNetworksListViewLayout.Row,
        in tableView: UITableView,
        at indexPath: IndexPath
    ) -> UITableViewCell {
        let cell: UITableViewCell

        switch viewModel {
        case .addNetwork:
            cell = UITableViewCell()
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
    }
}
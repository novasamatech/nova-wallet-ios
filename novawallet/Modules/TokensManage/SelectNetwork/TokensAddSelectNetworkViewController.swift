import UIKit
import Foundation_iOS

final class TokensAddSelectNetworkViewController: UIViewController, ViewHolder {
    typealias RootViewType = TokensAddSelectNetworkViewLayout

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, DiffableNetworkViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, DiffableNetworkViewModel>

    let presenter: TokensAddSelectNetworkPresenterProtocol

    private lazy var dataSource = makeDataSource()

    init(presenter: TokensAddSelectNetworkPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TokensAddSelectNetworkViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.headerView.valueTop.text = R.string(preferredLanguages: languages).localizable.addTokenNetworkSelectionTitle()
    }

    private func setupTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(TokensAddNetworkSelectionTableViewCell.self)
        rootView.tableView.rowHeight = 52.0
    }

    private func makeDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { tableView, _, viewModel in
            let cell = tableView.dequeueReusableCellWithType(TokensAddNetworkSelectionTableViewCell.self)
            cell?.bind(viewModel: viewModel.network)
            return cell
        }
    }
}

extension TokensAddSelectNetworkViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.selectChain(at: indexPath.row)
    }
}

extension TokensAddSelectNetworkViewController: TokensAddSelectNetworkViewProtocol {
    func didReceive(viewModels: [DiffableNetworkViewModel]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension TokensAddSelectNetworkViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

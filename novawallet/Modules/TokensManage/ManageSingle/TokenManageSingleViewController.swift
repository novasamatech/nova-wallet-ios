import UIKit

final class TokenManageSingleViewController: UIViewController, ViewHolder {
    enum Constants {
        static let bouncesOffset: CGFloat = 100
    }

    typealias RootViewType = TokenManageSingleViewLayout

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, TokenManageNetworkViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, TokenManageNetworkViewModel>

    let presenter: TokenManageSinglePresenterProtocol

    private lazy var dataSource = makeDataSource()

    init(presenter: TokenManageSinglePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TokenManageSingleViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.rowHeight = TokenManageSingleMeasurement.cellHeight
        rootView.tableView.registerClassForCell(TokenManageInstanceTableViewCell.self)
    }

    private func makeDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { [weak self] tableView, _, viewModel in
            let cell = tableView.dequeueReusableCellWithType(TokenManageInstanceTableViewCell.self)
            cell?.delegate = self

            cell?.bind(viewModel: viewModel)

            return cell
        }
    }
}

extension TokenManageSingleViewController: TokenManageSingleViewProtocol {
    func didReceiveNetwork(viewModels: [TokenManageNetworkViewModel]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func didReceiveTokenManage(viewModel: TokenManageViewModel) {
        rootView.tokenView.bind(viewModel: viewModel)
    }
}

extension TokenManageSingleViewController: UITableViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.bounces = scrollView.contentOffset.y > UIConstants.bouncesOffset
    }
}

extension TokenManageSingleViewController: TokenManageInstanceTableViewCellDelegate {
    func tokenManageInstanceCell(_ cell: TokenManageInstanceTableViewCell, didChangeSwitch enabled: Bool) {
        guard
            let indexPath = rootView.tableView.indexPath(for: cell),
            let viewModel = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        presenter.performSwitch(for: viewModel, enabled: enabled)
    }
}

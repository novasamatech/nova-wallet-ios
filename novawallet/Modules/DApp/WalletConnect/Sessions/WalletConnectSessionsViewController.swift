import UIKit
import Foundation_iOS

final class WalletConnectSessionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletConnectSessionsViewLayout

    let presenter: WalletConnectSessionsPresenterProtocol

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, WalletConnectSessionListViewModel>

    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, WalletConnectSessionListViewModel>

    private lazy var dataSource = createDataSource()

    init(
        presenter: WalletConnectSessionsPresenterProtocol,
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
        view = WalletConnectSessionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupTableView()
        setupHandlers()

        presenter.setup()
    }

    private func createDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { tableView, indexPath, viewModel -> UITableViewCell? in
            let cell: WalletConnectSessionCell = tableView.dequeueReusableCell(for: indexPath)
            cell.bind(viewModel: viewModel)
            return cell
        }
    }

    private func setupTableView() {
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self

        rootView.tableView.registerClassForCell(WalletConnectSessionCell.self)
    }

    private func setupHandlers() {
        rootView.scanButton.addTarget(
            self,
            action: #selector(actionScan),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        title = R.string.localizable.commonWalletConnect(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.scanButton.imageWithTitleView?.title = R.string.localizable.walletConnectScanButton(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.scanButton.invalidateLayout()
    }

    @objc func actionScan() {
        presenter.showScan()
    }
}

extension WalletConnectSessionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.showSession(at: indexPath.row)
    }
}

extension WalletConnectSessionsViewController: WalletConnectSessionsViewProtocol {
    func didReceive(viewModels: [WalletConnectSessionListViewModel]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels)

        let shouldAnimate = dataSource.numberOfSections(in: rootView.tableView) > 0

        dataSource.apply(snapshot, animatingDifferences: shouldAnimate)
    }
}

extension WalletConnectSessionsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

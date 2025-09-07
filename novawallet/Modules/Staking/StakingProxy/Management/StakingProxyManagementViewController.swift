import UIKit
import Foundation_iOS

final class StakingProxyManagementViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingProxyManagementViewLayout
    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, StakingProxyManagementViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, StakingProxyManagementViewModel>

    let presenter: StakingProxyManagementPresenterProtocol
    private lazy var dataSource = makeDataSource()

    init(
        presenter: StakingProxyManagementPresenterProtocol,
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
        view = StakingProxyManagementViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.rowHeight = 48
        rootView.tableView.registerClassForCell(WalletsListTableViewCell<WalletView, UIImageView>.self)
        rootView.tableView.registerHeaderFooterView(withClass: SectionTextHeaderView.self)
        rootView.tableView.delegate = self
    }

    private func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSetupYourProxies()

        rootView.addButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.delegationsAddTitle()
    }

    private func makeDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { tableView, _, viewModel in
            let cell = tableView.dequeueReusableCellWithType(WalletsListTableViewCell<WalletView, UIImageView>.self)
            cell?.contentDisplayView.valueView.image = R.image.iconMore()?.withTintColor(R.color.colorIconSecondary()!)
            cell?.infoView.bind(viewModel: viewModel.info)
            return cell
        }
    }

    private func setupHandlers() {
        rootView.addButton.addTarget(
            self,
            action: #selector(actionAddProxy),
            for: .touchUpInside
        )
    }

    @objc private func actionAddProxy() {
        presenter.addProxy()
    }
}

extension StakingProxyManagementViewController: StakingProxyManagementViewProtocol {
    func didReceive(viewModels: [StakingProxyManagementViewModel]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels)

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension StakingProxyManagementViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if let model = dataSource.itemIdentifier(for: indexPath) {
            presenter.showOptions(account: model.account)
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        41
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let header: SectionTextHeaderView = tableView.dequeueReusableHeaderFooterView()
        let text = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingProxyManagementTitle()
        header.bind(text: text)
        return header
    }
}

extension StakingProxyManagementViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.tableView.reloadData()
        }
    }
}

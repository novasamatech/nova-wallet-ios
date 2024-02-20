import UIKit
import SoraFoundation

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
        rootView.tableView.registerClassForCell(WalletsListTableViewCell<UIImageView>.self)
        rootView.tableView.registerHeaderFooterView(withClass: SectionTextHeaderView.self)
        rootView.tableView.delegate = self
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingSetupYourProxies(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.addButton.imageWithTitleView?.title = R.string.localizable.delegationsAddTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func makeDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { tableView, _, viewModel in
            let cell = tableView.dequeueReusableCellWithType(WalletsListTableViewCell<UIImageView>.self)
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
        let text = R.string.localizable.stakingProxyManagementTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
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

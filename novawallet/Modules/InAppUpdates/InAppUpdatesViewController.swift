import UIKit
import SoraFoundation

final class InAppUpdatesViewController: UIViewController, ViewHolder {
    typealias RootViewType = InAppUpdatesViewLayout

    let presenter: InAppUpdatesPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, VersionTableViewCell.Model>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, VersionTableViewCell.Model>
    private var dataSource: DataSource?
    private var isCriticalBanner: Bool = false
    private var isAvailableMoreVersions: Bool = false

    init(
        presenter: InAppUpdatesPresenterProtocol,
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
        view = InAppUpdatesViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource = createDataSource()
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self

        setupNavigationItem()
        setupInstallButton()

        presenter.setup()
    }

    private func createDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { [weak self] tableView, indexPath, model -> UITableViewCell? in
            guard let self = self else {
                return nil
            }

            let cell: VersionTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.bind(model: model, locale: self.selectedLocale)
            return cell
        }
    }

    private func setupNavigationItem() {
        navigationItem.title = "Update available"
        navigationItem.rightBarButtonItem = .init(
            title: "Skip",
            style: .plain,
            target: self,
            action: #selector(didTapOnSkipButton)
        )
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem?.tintColor = R.color.colorButtonTextAccent()
    }

    private func setupInstallButton() {
        rootView.installButton.imageWithTitleView?.title = "Install"
        rootView.installButton.addTarget(self, action: #selector(didTapOnInstallButton), for: .touchUpInside)
    }

    private func setupLocalization() {
        navigationItem.title = "Update available"
        navigationItem.rightBarButtonItem?.title = "Skip"
        rootView.installButton.imageWithTitleView?.title = "Install"
        rootView.tableView.reloadData()
    }

    @objc private func didTapOnSkipButton() {
        presenter.skip()
    }

    @objc private func didTapOnLoadMoreVersions() {
        presenter.loadMoreVersions()
    }

    @objc private func didTapOnInstallButton() {
        presenter.installLastVersion()
    }
}

extension InAppUpdatesViewController: InAppUpdatesViewProtocol {
    func didReceive(versionModels: [VersionTableViewCell.Model], isAvailableMoreVersions: Bool) {
        self.isAvailableMoreVersions = isAvailableMoreVersions

        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(versionModels)
        dataSource?.apply(snapshot, animatingDifferences: true)
    }

    func didReceive(isCriticalBanner: Bool) {
        self.isCriticalBanner = isCriticalBanner
        rootView.tableView.reloadData()
    }
}

extension InAppUpdatesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let selectedItem = dataSource?.itemIdentifier(for: indexPath) else {
            return
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let view: GradientBannerHeaderView = tableView.dequeueReusableHeaderFooterView()
        view.bind(isCritical: isCriticalBanner, locale: selectedLocale)
        return view
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection _: Int) -> UIView? {
        guard isAvailableMoreVersions else {
            return nil
        }
        let view: LoadMoreFooterView = tableView.dequeueReusableHeaderFooterView()
        view.bind(text: "See all available updates")
        view.moreButton.addTarget(self, action: #selector(didTapOnLoadMoreVersions), for: .touchUpInside)
        return view
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        132
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        34
    }
}

extension InAppUpdatesViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

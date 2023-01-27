import UIKit
import SoraFoundation

final class InAppUpdatesViewController: UIViewController, ViewHolder {
    typealias RootViewType = InAppUpdatesViewLayout

    let presenter: InAppUpdatesPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<Section, Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Row>
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

            switch model {
            case let .banner(isCritical):
                let view: GradientBannerHeaderView = tableView.dequeueReusableCell(for: indexPath)
                view.bind(isCritical: isCritical, locale: self.selectedLocale)
                return view
            case let .version(viewModel):
                let cell: VersionTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.bind(model: viewModel, locale: self.selectedLocale)
                return cell
            }
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

    private func showFooter(for section: Int) -> Bool {
        if #available(iOS 15.0, *) {
            switch dataSource?.sectionIdentifier(for: section) {
            case .banner, .none:
                return false
            case let .main(showFooter):
                return showFooter
            }
        } else {
            return isAvailableMoreVersions && section == 1
        }
    }
}

extension InAppUpdatesViewController: InAppUpdatesViewProtocol {
    func didReceive(
        versionModels: [VersionTableViewCell.Model],
        isCriticalBanner: Bool,
        isAvailableMoreVersions: Bool
    ) {
        self.isAvailableMoreVersions = isAvailableMoreVersions
        let bannerSection = Section.banner
        let mainSection = Section.main(showFooter: isAvailableMoreVersions)
        let versionsViewModels = versionModels.map { Row.version($0) }
        let bannerViewModel = Row.banner(isCritical: isCriticalBanner)

        var snapshot = Snapshot()
        snapshot.appendSections([bannerSection, mainSection])
        snapshot.appendItems([bannerViewModel], toSection: bannerSection)
        snapshot.appendItems(versionsViewModels, toSection: mainSection)
        dataSource?.apply(snapshot, animatingDifferences: true)
    }
}

extension InAppUpdatesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let selectedItem = dataSource?.itemIdentifier(for: indexPath) else {
            return
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard showFooter(for: section) else {
            return nil
        }

        let view: LoadMoreFooterView = tableView.dequeueReusableHeaderFooterView()
        view.bind(text: "See all available updates")
        view.moreButton.addTarget(self, action: #selector(didTapOnLoadMoreVersions), for: .touchUpInside)
        return view
    }

    func tableView(_: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        showFooter(for: section) ? 34 : 0
    }
}

extension InAppUpdatesViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension InAppUpdatesViewController {
    enum Section: Hashable {
        case banner
        case main(showFooter: Bool)
    }

    enum Row: Hashable {
        case banner(isCritical: Bool)
        case version(VersionTableViewCell.Model)
    }
}

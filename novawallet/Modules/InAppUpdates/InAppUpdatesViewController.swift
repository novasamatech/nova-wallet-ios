import UIKit
import SoraFoundation

final class InAppUpdatesViewController: UIViewController, ViewHolder {
    typealias RootViewType = InAppUpdatesViewLayout

    let presenter: InAppUpdatesPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<Section, Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Row>
    private var dataSource: DataSource?
    private var isCriticalBanner: Bool = false
    private var isAvailableMoreVersionsModel: LoadableViewModelState<String> = .cached(value: "")

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
        let dataSource = DataSource(tableView: rootView.tableView) { [weak self] tableView, indexPath, model in
            guard let self = self else {
                return nil
            }

            switch model {
            case let .banner(isCritical):
                let view: GradientBannerTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                view.bind(isCritical: isCritical, locale: self.selectedLocale)
                return view
            case let .version(viewModel):
                let cell: VersionTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.bind(model: viewModel, locale: self.selectedLocale)
                return cell
            }
        }

        dataSource.defaultRowAnimation = .fade
        return dataSource
    }

    private func setupNavigationItem() {
        navigationItem.title = R.string.localizable.inAppUpdatesTitle(preferredLanguages: selectedLocale.rLanguages)
        let skipButtonTitle = R.string.localizable.commonSkip(preferredLanguages: selectedLocale.rLanguages)
        navigationItem.rightBarButtonItem = .init(
            title: skipButtonTitle,
            style: .plain,
            target: self,
            action: #selector(didTapOnSkipButton)
        )
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem?.tintColor = R.color.colorButtonTextAccent()
    }

    private func setupInstallButton() {
        let preferredLanguages = selectedLocale.rLanguages
        rootView.installButton.imageWithTitleView?.title =
            R.string.localizable.inAppUpdatesInstallButtonTitle(preferredLanguages: preferredLanguages)
        rootView.installButton.addTarget(self, action: #selector(didTapOnInstallButton), for: .touchUpInside)
    }

    private func setupLocalization() {
        let strings = R.string.localizable.self
        let preferredLanguages = selectedLocale.rLanguages
        navigationItem.title = strings.inAppUpdatesTitle(preferredLanguages: preferredLanguages)
        navigationItem.rightBarButtonItem?.title = strings.commonSkip(preferredLanguages: preferredLanguages)
        rootView.installButton.imageWithTitleView?.title =
            strings.inAppUpdatesInstallButtonTitle(preferredLanguages: preferredLanguages)
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

    private func footerViewModel(for section: Int) -> LoadableViewModelState<String>? {
        if #available(iOS 15.0, *) {
            switch dataSource?.sectionIdentifier(for: section) {
            case .banner, .none:
                return nil
            case let .main(footer):
                return footer.value?.isEmpty == true ? nil : footer
            }
        } else {
            return section == 1 ? isAvailableMoreVersionsModel : nil
        }
    }
}

extension InAppUpdatesViewController: InAppUpdatesViewProtocol {
    func didReceive(
        versionModels: [VersionTableViewCell.Model],
        isCriticalBanner: Bool,
        isAvailableMoreVersionsModel: LoadableViewModelState<String>
    ) {
        self.isAvailableMoreVersionsModel = isAvailableMoreVersionsModel
        let bannerSection = Section.banner
        let mainSection = Section.main(footer: isAvailableMoreVersionsModel)
        let versionsViewModels = versionModels.map { Row.version($0) }
        let bannerViewModel = Row.banner(isCritical: isCriticalBanner)

        var snapshot = Snapshot()
        snapshot.appendSections([bannerSection, mainSection])
        snapshot.appendItems([bannerViewModel], toSection: bannerSection)
        snapshot.appendItems(versionsViewModels, toSection: mainSection)
        dataSource?.apply(snapshot, animatingDifferences: versionModels.count > 1)
    }
}

extension InAppUpdatesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard let footerViewModel = footerViewModel(for: section) else {
            return nil
        }

        let view: LoadMoreFooterView = tableView.dequeueReusableHeaderFooterView()
        view.bind(text: footerViewModel)
        view.moreButton.addTarget(self, action: #selector(didTapOnLoadMoreVersions), for: .touchUpInside)
        return view
    }

    func tableView(_: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        footerViewModel(for: section) == nil ? .leastNormalMagnitude : 34
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
        case main(footer: LoadableViewModelState<String>)
    }

    enum Row: Hashable {
        case banner(isCritical: Bool)
        case version(VersionTableViewCell.Model)
    }
}

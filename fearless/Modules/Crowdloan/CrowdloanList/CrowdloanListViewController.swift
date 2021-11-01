import UIKit
import SoraFoundation
import SoraUI

final class CrowdloanListViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanListViewLayout

    let presenter: CrowdloanListPresenterProtocol

    private var chainInfo: CrowdloansChainViewModel?
    private var state: CrowdloanListState = .loading

    private var shouldUpdateOnAppearance: Bool = false

    init(
        presenter: CrowdloanListPresenterProtocol,
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
        view = CrowdloanListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
        applyState()

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if shouldUpdateOnAppearance {
            presenter.refresh(shouldReset: false)
        } else {
            shouldUpdateOnAppearance = true
        }

        presenter.becomeOnline()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        presenter.putOffline()
    }

    func configure() {
        rootView.tableView.registerClassForCell(CrowdloanChainTableViewCell.self)
        rootView.tableView.registerClassForCell(YourCrowdloansTableViewCell.self)
        rootView.tableView.registerClassForCell(CrowdloanTableViewCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CrowdloanStatusSectionView.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        if let refreshControl = rootView.tableView.refreshControl {
            refreshControl.addTarget(self, action: #selector(actionRefresh), for: .valueChanged)
        }
        rootView.headerView.chainSelectionView.addTarget(
            self,
            action: #selector(actionSelectChain),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.headerView.titleLabel.text = R.string.localizable
            .tabbarCrowdloanTitle_v190(preferredLanguages: languages)
    }

    private func applyState() {
        switch state {
        case .loading:
            didStartLoading()

            rootView.bringSubviewToFront(rootView.tableView)
        case .loaded:
            rootView.tableView.refreshControl?.endRefreshing()
            didStopLoading()

            rootView.bringSubviewToFront(rootView.tableView)
        case .empty, .error:
            rootView.tableView.refreshControl?.endRefreshing()
            didStopLoading()

            rootView.bringSubviewToFront(rootView.statusView)
        }

        rootView.tableView.reloadData()
        reloadEmptyState(animated: false)
    }

    @objc func actionRefresh() {
        presenter.refresh(shouldReset: false)
    }

    @objc func actionSelectChain() {
        presenter.selectChain()
    }
}

extension CrowdloanListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        switch state {
        case let .loaded(viewModel):
            return viewModel.sections.count
        case .loading, .empty, .error:
            return 0
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch state {
        case let .loaded(viewModel):
            let sectionModel = viewModel.sections[section]
            switch sectionModel {
            case .yourContributions:
                return 1
            case let .active(_, cellViewModels):
                return cellViewModels.count
            case let .completed(_, cellViewModels):
                return cellViewModels.count
            }
        case .loading, .empty, .error:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch state {
        case let .loaded(viewModel):
            let sectionModel = viewModel.sections[indexPath.section]
            switch sectionModel {
            case let .yourContributions(title, contrubutionsCount):
                let cell = tableView.dequeueReusableCellWithType(YourCrowdloansTableViewCell.self)!
                cell.bind(title: title, count: contrubutionsCount)
                return cell
            case let .active(_, cellViewModels), let .completed(_, cellViewModels):
                let cell = tableView.dequeueReusableCellWithType(CrowdloanTableViewCell.self)!
                let cellViewModel = cellViewModels[indexPath.row]
                cell.bind(viewModel: cellViewModel)
                return cell
            }
        case .loading, .empty, .error:
            return UITableViewCell()
        }
    }
}

extension CrowdloanListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .loaded(viewModel) = state else {
            return
        }

        let sectionModel = viewModel.sections[indexPath.section]
        switch sectionModel {
        case let .active(_, cellViewModels):
            let viewModel = cellViewModels[indexPath.row]
            presenter.selectViewModel(viewModel)
        case .yourContributions:
            presenter.handleYourContributions()
        default:
            return
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case let .loaded(viewModel) = state else {
            return nil
        }

        let sectionModel = viewModel.sections[section]
        switch sectionModel {
        case let .active(title, cells), let .completed(title, cells):
            let headerView: CrowdloanStatusSectionView = tableView.dequeueReusableHeaderFooterView()
            headerView.bind(title: title, count: cells.count)
            return headerView
        default:
            return nil
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard case let .loaded(viewModel) = state else {
            return 0.0
        }

        let sectionModel = viewModel.sections[section]
        switch sectionModel {
        case .active, .completed:
            return UITableView.automaticDimension
        default:
            return 0.0
        }
    }
}

extension CrowdloanListViewController: CrowdloanListViewProtocol {
    func didReceive(chainInfo: CrowdloansChainViewModel) {
        self.chainInfo = chainInfo

        rootView.headerView.bind(viewModel: chainInfo)
        rootView.headerView.setNeedsLayout()
        rootView.headerView.layoutIfNeeded()
    }

    func didReceive(listState: CrowdloanListState) {
        state = listState

        applyState()
    }
}

extension CrowdloanListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension CrowdloanListViewController: LoadableViewProtocol {
    var loadableContentView: UIView! { rootView.statusView }
}

extension CrowdloanListViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
    var contentViewForEmptyState: UIView { rootView.statusView }
}

extension CrowdloanListViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        switch state {
        case let .error(message):
            let errorView = ErrorStateView()
            errorView.errorDescriptionLabel.text = message
            errorView.delegate = self
            errorView.locale = selectedLocale
            return errorView
        case .empty:
            let emptyView = EmptyStateView()
            emptyView.image = R.image.iconEmptyHistory()
            emptyView.title = R.string.localizable
                .crowdloanEmptyMessage(preferredLanguages: selectedLocale.rLanguages)
            emptyView.titleColor = R.color.colorLightGray()!
            emptyView.titleFont = .p2Paragraph
            return emptyView
        case .loading, .loaded:
            return nil
        }
    }
}

extension CrowdloanListViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        switch state {
        case .error, .empty:
            return true
        case .loading, .loaded:
            return false
        }
    }
}

extension CrowdloanListViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.refresh(shouldReset: true)
    }
}

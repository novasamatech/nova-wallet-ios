import UIKit
import UIKit_iOS
import Foundation_iOS

final class NominationPoolSearchViewController: BaseTableSearchViewController {
    typealias RootViewType = NominationPoolSearchViewLayout

    var presenter: NominationPoolSearchPresenterProtocol? {
        basePresenter as? NominationPoolSearchPresenterProtocol
    }

    let keyboardAppearanceStrategy: KeyboardAppearanceStrategyProtocol
    private var state: GenericViewState<[StakingSelectPoolViewModel]> = .loaded(viewModel: [])

    init(
        presenter: NominationPoolSearchPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        keyboardAppearanceStrategy: KeyboardAppearanceStrategyProtocol
    ) {
        self.keyboardAppearanceStrategy = keyboardAppearanceStrategy
        super.init(basePresenter: presenter)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NominationPoolSearchViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLocalization()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardAppearanceStrategy.onViewWillAppear(for: rootView.searchField)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        keyboardAppearanceStrategy.onViewDidAppear(for: rootView.searchField)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        rootView.searchField.resignFirstResponder()
    }

    private func setupTableView() {
        rootView.tableView.registerClassForCell(StakingPoolTableViewCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: StakingSelectPoolListHeaderView.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    private func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSearch()
        rootView.searchField.placeholder = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.stakingSearchPoolPlaceholder()
        rootView.tableView.reloadData()
    }
}

extension NominationPoolSearchViewController: NominationPoolSearchViewProtocol {
    func didReceivePools(state: GenericViewState<[StakingSelectPoolViewModel]>) {
        guard let rootView = self.rootView as? NominationPoolSearchViewLayout else {
            return
        }
        self.state = state
        rootView.tableView.isHidden = shouldDisplayEmptyState
        reloadEmptyState(animated: false)

        switch state {
        case .loading:
            rootView.loadingView.isHidden = false
            rootView.loadingView.start()
        case let .loaded(viewModels):
            rootView.loadingView.isHidden = true
            rootView.loadingView.stop()

            guard !viewModels.isEmpty else {
                return
            }
            rootView.tableView.reloadData()
        case .error:
            rootView.loadingView.isHidden = true
            rootView.loadingView.stop()
        }
    }
}

extension NominationPoolSearchViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        state.viewModel?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: StakingPoolTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        if let model = state.viewModel?[safe: indexPath.row] {
            cell.bind(viewModel: model)
            cell.infoAction = { [weak self] viewModel in
                self?.presenter?.showPoolInfo(poolId: viewModel.id)
            }
        }
        return cell
    }
}

extension NominationPoolSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let model = state.viewModel?[safe: indexPath.row] else {
            return
        }
        presenter?.selectPool(poolId: model.id)
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        44
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard let viewModels = state.viewModel, !viewModels.isEmpty else {
            return 0
        }
        return 29
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let viewModels = state.viewModel, !viewModels.isEmpty else {
            return nil
        }
        let header: StakingSelectPoolListHeaderView = tableView.dequeueReusableHeaderFooterView()
        let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSearchResultsNumber(viewModels.count)
        let details = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.stakingSelectPoolMembers()

        header.bind(
            title: title,
            details: details
        )
        return header
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension NominationPoolSearchViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension NominationPoolSearchViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyStateView()
        switch state {
        case let .error(text):
            emptyView.image = R.image.iconEmptySearch()
            emptyView.title = text
        case .loaded:
            emptyView.image = R.image.iconStartSearch()
            emptyView.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSearchStartTitle_v2_2_0()
        case .loading:
            return nil
        }

        emptyView.titleColor = R.color.colorTextSecondary()!
        emptyView.titleFont = .regularFootnote
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.contentView
    }

    var verticalSpacingForEmptyState: CGFloat? {
        26
    }
}

// MARK: - EmptyStateDelegate

extension NominationPoolSearchViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        switch state {
        case .error:
            return true
        case let .loaded(viewModels):
            return viewModels.isEmpty
        case .loading:
            return false
        }
    }
}

extension NominationPoolSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

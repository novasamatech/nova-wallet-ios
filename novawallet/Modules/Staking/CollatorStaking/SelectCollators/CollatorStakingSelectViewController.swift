import UIKit
import Foundation_iOS
import UIKit_iOS

final class CollatorStakingSelectViewController: UIViewController, ViewHolder {
    typealias RootViewType = CollatorStakingSelectViewLayout

    let presenter: CollatorStakingSelectPresenterProtocol

    private var collatorViewModels: [CollatorSelectionViewModel] {
        state?.viewModel?.collators ?? []
    }

    private var sorting: CollatorsSortType {
        state?.viewModel?.sorting ?? .rewards
    }

    private var headerViewModel: TitleWithSubtitleViewModel? {
        state?.viewModel?.header
    }

    private var filtersApplied: Bool {
        state?.viewModel?.filtersApplied ?? false
    }

    private var state: CollatorSelectionState?

    init(
        presenter: CollatorStakingSelectPresenterProtocol,
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
        view = CollatorStakingSelectViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupBarItems()
        setupLocalization()
        setupHandlers()
        updateClearButton()

        presenter.setup()
    }

    private func setupBarItems() {
        let filterBarItem = UIBarButtonItem(customView: rootView.filterButton)
        let searchBarItem = UIBarButtonItem(customView: rootView.searchButton)

        navigationItem.rightBarButtonItems = [filterBarItem, searchBarItem]

        rootView.filterButton.addTarget(
            self,
            action: #selector(actionFilter),
            for: .touchUpInside
        )

        rootView.searchButton.addTarget(
            self,
            action: #selector(actionSearch),
            for: .touchUpInside
        )
    }

    private func setupHandlers() {
        rootView.clearButton.addTarget(self, action: #selector(actionClear), for: .touchUpInside)
    }

    private func setupTableView() {
        rootView.tableView.registerClassForCell(CollatorSelectionCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CustomValidatorListHeaderView.self)

        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.rowHeight = 44.0
    }

    private func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.parachainStakingSelectCollator()

        rootView.clearButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingCustomClearButtonTitle()

        rootView.clearButton.invalidateLayout()
    }

    private func updateSetFiltersButton() {
        let image = filtersApplied ? R.image.iconFilterActive() : R.image.iconFilter()
        rootView.filterButton.setImage(image, for: .normal)
    }

    private func updateClearButton() {
        rootView.clearButton.isUserInteractionEnabled = filtersApplied

        if filtersApplied {
            rootView.clearButton.applyEnabledSecondaryStyle()
        } else {
            rootView.clearButton.applyDisabledSecondaryStyle()
        }
    }

    private func applyState() {
        switch state {
        case .error, .loading, .none:
            navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = false }
            rootView.tableView.isHidden = true
        case .loaded:
            navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = true }
            rootView.tableView.isHidden = false
        }

        updateClearButton()
        updateSetFiltersButton()
    }

    @objc private func actionSearch() {
        presenter.presentSearch()
    }

    @objc private func actionFilter() {
        presenter.presenterFilters()
    }

    @objc private func actionClear() {
        presenter.clearFilters()
    }
}

// MARK: - UITableViewDataSource

extension CollatorStakingSelectViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        collatorViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(CollatorSelectionCell.self)!
        cell.delegate = self

        let viewModel = collatorViewModels[indexPath.row]

        let displayType: CollatorSelectionCell.DisplayType

        switch sorting {
        case .rewards:
            displayType = .accentOnSorting
        case .minStake, .totalStake, .ownStake:
            displayType = .accentOnDetails
        }

        cell.bind(viewModel: viewModel, type: displayType)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension CollatorStakingSelectViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.selectCollator(at: indexPath.row)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard headerViewModel != nil else { return 0 }
        return 26.0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let headerViewModel = headerViewModel else { return nil }
        let headerView: CustomValidatorListHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(viewModel: headerViewModel)
        return headerView
    }
}

extension CollatorStakingSelectViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.refresh()
    }
}

extension CollatorStakingSelectViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension CollatorStakingSelectViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let state = state else { return nil }

        switch state {
        case let .error(error):
            let errorView = ErrorStateView()
            errorView.errorDescriptionLabel.text = error
            errorView.delegate = self
            errorView.locale = selectedLocale
            return errorView
        case .loading:
            let loadingView = ListLoadingView()
            loadingView.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonLoadingCollators()
            loadingView.start()
            return loadingView
        case .loaded:
            return nil
        }
    }
}

extension CollatorStakingSelectViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let state = state else { return false }
        switch state {
        case .error, .loading:
            return true
        case .loaded:
            return false
        }
    }
}

extension CollatorStakingSelectViewController: CollatorSelectionCellDelegate {
    func didTapInfoButton(in cell: CollatorSelectionCell) {
        if let indexPath = rootView.tableView.indexPath(for: cell) {
            presenter.presentCollator(at: indexPath.row)
        }
    }
}

extension CollatorStakingSelectViewController: CollatorStakingSelectViewProtocol {
    func didReceive(state: CollatorSelectionState) {
        self.state = state

        rootView.tableView.reloadData()

        applyState()

        reloadEmptyState(animated: false)
    }
}

extension CollatorStakingSelectViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

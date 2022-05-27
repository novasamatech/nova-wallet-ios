import UIKit
import SoraFoundation

final class ParaStkSelectCollatorsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ParaStkSelectCollatorsViewLayout

    let presenter: ParaStkSelectCollatorsPresenterProtocol

    private var collatorViewModels: [CollatorSelectionViewModel] {
        viewModel?.collators ?? []
    }

    private var sorting: CollatorsSortType {
        viewModel?.sorting ?? .rewards
    }

    private var headerViewModel: TitleWithSubtitleViewModel? {
        viewModel?.header
    }

    private var viewModel: CollatorSelectionScreenViewModel?

    init(
        presenter: ParaStkSelectCollatorsPresenterProtocol,
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
        view = ParaStkSelectCollatorsViewLayout()
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
        navigationItem.rightBarButtonItems = [rootView.searchButton, rootView.filterButton]

        rootView.searchButton.target = self
        rootView.searchButton.action = #selector(actionSearch)

        rootView.filterButton.target = self
        rootView.filterButton.action = #selector(actionFilter)
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
        title = R.string.localizable.parachainStakingSelectCollator(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.clearButton.imageWithTitleView?.title = R.string.localizable.stakingCustomClearButtonTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.clearButton.invalidateLayout()
    }

    private func updateClearButton() {
        let isEnabled = sorting != CollatorsSortType.defaultType
        rootView.clearButton.isUserInteractionEnabled = isEnabled

        if isEnabled {
            rootView.clearButton.applyEnabledSecondaryStyle()
        } else {
            rootView.clearButton.applyDisabledSecondaryStyle()
        }
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

extension ParaStkSelectCollatorsViewController: UITableViewDataSource {
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

extension ParaStkSelectCollatorsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
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

// MARK: - CustomValidatorCellDelegate

extension ParaStkSelectCollatorsViewController: CollatorSelectionCellDelegate {
    func didTapInfoButton(in cell: CollatorSelectionCell) {
        if let indexPath = rootView.tableView.indexPath(for: cell) {
            presenter.presentCollatorInfo(at: indexPath.row)
        }
    }
}

extension ParaStkSelectCollatorsViewController: ParaStkSelectCollatorsViewProtocol {
    func didReceive(viewModel: CollatorSelectionScreenViewModel) {
        self.viewModel = viewModel

        rootView.tableView.reloadData()

        updateClearButton()
    }
}

extension ParaStkSelectCollatorsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

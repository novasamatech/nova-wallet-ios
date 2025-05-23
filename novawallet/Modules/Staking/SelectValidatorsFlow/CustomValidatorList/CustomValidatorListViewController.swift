import UIKit
import Foundation_iOS
import UIKit_iOS

final class CustomValidatorListViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = CustomValidatorListViewLayout

    let presenter: CustomValidatorListPresenterProtocol
    let selectedValidatorsLimit: Int

    private var cellViewModels: [CustomValidatorCellViewModel] = []
    private var headerViewModel: TitleWithSubtitleViewModel?
    private var selectedValidatorsCount: Int = 0
    private var electedValidatorsCount: Int = 0

    private var filterIsApplied: Bool = true

    let searchButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconSearchWhite(), for: .normal)
        return button
    }()

    let filterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconFilterActive(), for: .normal)
        return button
    }()

    // MARK: - Lifecycle

    init(
        presenter: CustomValidatorListPresenterProtocol,
        selectedValidatorsLimit: Int,
        localizationManager: LocalizationManagerProtocol? = nil
    ) {
        self.presenter = presenter
        self.selectedValidatorsLimit = selectedValidatorsLimit

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CustomValidatorListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        setupTable()
        setupNavigationBar()
        setupActionButtons()
        presenter.setup()
    }

    // MARK: - Private functions

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(CustomValidatorCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CustomValidatorListHeaderView.self)
        rootView.tableView.rowHeight = 44.0
    }

    private func setupNavigationBar() {
        let filterBarbutton = UIBarButtonItem(customView: filterButton)
        let searchBarbutton = UIBarButtonItem(customView: searchButton)

        navigationItem.rightBarButtonItems = [filterBarbutton,
                                              searchBarbutton]

        filterButton.addTarget(self, action: #selector(tapFilterButton), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(tapSearchButton), for: .touchUpInside)
    }

    private func setupActionButtons() {
        rootView.fillRestButton.addTarget(self, action: #selector(tapFillRestButton), for: .touchUpInside)
        rootView.clearButton.addTarget(self, action: #selector(tapClearButton), for: .touchUpInside)
        rootView.deselectButton.addTarget(self, action: #selector(tapDeselectButton), for: .touchUpInside)
        rootView.proceedButton.addTarget(self, action: #selector(tapProceedButton), for: .touchUpInside)

        updateFillRestButton()
        updateDeselectButton()
        updateProceedButton()
    }

    private func updateSetFiltersButton() {
        let image = filterIsApplied ? R.image.iconFilterActive() : R.image.iconFilter()
        filterButton.setImage(image, for: .normal)
    }

    private func updateFillRestButton() {
        let isEnabled = selectedValidatorsCount < selectedValidatorsLimit
        rootView.fillRestButton.isEnabled = isEnabled

        if isEnabled {
            rootView.fillRestButton.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundPrimary()!
            rootView.fillRestButton.imageWithTitleView?.titleColor = R.color.colorButtonText()!
        } else {
            rootView.fillRestButton.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundInactive()!
            rootView.fillRestButton.imageWithTitleView?.titleColor = R.color.colorButtonTextInactive()!
        }
    }

    private func updateClearFiltersButton() {
        rootView.clearButton.isEnabled = filterIsApplied

        applyDarkButtonStyle(rootView.clearButton, isEnabled: filterIsApplied)
    }

    private func updateDeselectButton() {
        let isEnabled = selectedValidatorsCount > 0
        rootView.deselectButton.isEnabled = isEnabled

        applyDarkButtonStyle(rootView.deselectButton, isEnabled: isEnabled)
    }

    private func applyDarkButtonStyle(_ button: RoundedButton, isEnabled: Bool) {
        if isEnabled {
            button.applyEnabledSecondaryStyle()
        } else {
            button.applyDisabledSecondaryStyle()
        }
    }

    private func updateProceedButton() {
        let buttonTitle: String
        let isEnabled: Bool

        if selectedValidatorsCount == 0 {
            isEnabled = false

            buttonTitle = R.string.localizable
                .stakingCustomProceedButtonDisabledTitle(
                    selectedValidatorsLimit,
                    preferredLanguages: selectedLocale.rLanguages
                )

        } else {
            isEnabled = true

            buttonTitle = R.string.localizable
                .stakingCustomProceedButtonEnabledTitle(
                    selectedValidatorsCount,
                    selectedValidatorsLimit,
                    preferredLanguages: selectedLocale.rLanguages
                )
        }

        rootView.proceedButton.imageWithTitleView?.title = buttonTitle
        rootView.proceedButton.set(enabled: isEnabled)
    }

    private func presentValidatorInfo(at index: Int) {
        presenter.didSelectValidator(at: index)
    }

    // MARK: - Actions

    @objc private func tapFilterButton() {
        presenter.presentFilter()
    }

    @objc private func tapSearchButton() {
        presenter.presentSearch()
    }

    @objc private func tapFillRestButton() {
        presenter.fillWithRecommended()
    }

    @objc private func tapClearButton() {
        presenter.clearFilter()
    }

    @objc private func tapDeselectButton() {
        presenter.deselectAll()
    }

    @objc private func tapProceedButton() {
        presenter.proceed()
    }
}

// MARK: - Localizable

extension CustomValidatorListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .stakingCustomValidatorsListTitle(preferredLanguages: selectedLocale.rLanguages)

            rootView.fillRestButton.imageWithTitleView?.title = R.string.localizable
                .stakingCustomFillButtonTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.clearButton.imageWithTitleView?.title = R.string.localizable
                .stakingCustomClearButtonTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.deselectButton.imageWithTitleView?.title = R.string.localizable
                .stakingCustomDeselectButtonTitle(preferredLanguages: selectedLocale.rLanguages)

            updateProceedButton()
        }
    }
}

// MARK: - CustomValidatorListViewProtocol

extension CustomValidatorListViewController: CustomValidatorListViewProtocol {
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]? = nil) {
        cellViewModels = viewModel.cellViewModels
        headerViewModel = viewModel.headerViewModel
        selectedValidatorsCount = viewModel.selectedValidatorsCount

        if let indexes = indexes {
            let indexPaths = indexes.map {
                IndexPath(row: $0, section: 0)
            }

            UIView.performWithoutAnimation {
                rootView.tableView.reloadRows(at: indexPaths, with: .automatic)
            }
        } else {
            rootView.tableView.reloadData()
        }

        updateFillRestButton()
        updateDeselectButton()
        updateProceedButton()
    }

    func setFilterAppliedState(to applied: Bool) {
        filterIsApplied = applied
        updateClearFiltersButton()
        updateSetFiltersButton()
    }

    func updateHeaderViewModel(to viewModel: TitleWithSubtitleViewModel) {
        headerViewModel = viewModel
    }
}

// MARK: - UITableViewDataSource

extension CustomValidatorListViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        cellViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(CustomValidatorCell.self)!
        cell.delegate = self

        let viewModel = cellViewModels[indexPath.row]
        cell.bind(viewModel: viewModel)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension CustomValidatorListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.changeValidatorSelection(at: indexPath.row)
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

extension CustomValidatorListViewController: CustomValidatorCellDelegate {
    func didTapInfoButton(in cell: CustomValidatorCell) {
        if let indexPath = rootView.tableView.indexPath(for: cell) {
            presentValidatorInfo(at: indexPath.row)
        }
    }
}

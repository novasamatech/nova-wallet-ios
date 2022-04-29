import UIKit
import SoraFoundation

final class ValidatorListFilterViewController: UIViewController, ViewHolder {
    typealias RootViewType = ValidatorListFilterViewLayout

    let presenter: ValidatorListFilterPresenterProtocol

    private var viewModel: ValidatorListFilterViewModel?

    // MARK: - Lifecycle

    init(
        presenter: ValidatorListFilterPresenterProtocol,
        localizationManager: LocalizationManager
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
        view = ValidatorListFilterViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.view = self

        setupResetButton()
        setupApplyButton()
        setupTableView()
        applyLocalization()

        presenter.setup()
    }

    // MARK: - Private functions

    private func setupTableView() {
        rootView.tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)
        rootView.tableView.registerClassForCell(TitleSubtitleSwitchTableViewCell.self)
        rootView.tableView.registerClassForCell(ValidatorListFilterSortCell.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.tableView.separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
    }

    private func setupResetButton() {
        let resetButton = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(didTapResetButton)
        )

        resetButton.setupDefaultTitleStyle(with: .regularBody)

        navigationItem.rightBarButtonItem = resetButton
    }

    private func setupApplyButton() {
        rootView.applyButton.addTarget(
            self,
            action: #selector(didTapApplyButton),
            for: .touchUpInside
        )
    }

    private func updateActionButtons() {
        let isEnabled = viewModel?.canApply ?? false
        rootView.applyButton.isUserInteractionEnabled = isEnabled

        if isEnabled {
            rootView.applyButton.applyEnabledStyle()
        } else {
            rootView.applyButton.applyTranslucentDisabledStyle()
        }

        navigationItem.rightBarButtonItem?.isEnabled = viewModel?.canReset ?? false
    }

    // MARK: - Actions

    @objc
    func didTapApplyButton() {
        presenter.applyFilter()
    }

    @objc
    func didTapResetButton() {
        presenter.resetFilter()
    }
}

// MARK: - UITableViewDataSource

extension ValidatorListFilterViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        2
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }

        switch section {
        case 0:
            return viewModel.filterModel.cellViewModels.count
        case 1:
            return viewModel.sortModel.cellViewModels.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else { return UITableViewCell() }

        switch indexPath.section {
        case 0:
            let item = viewModel.filterModel.cellViewModels[indexPath.row]
            let cell = tableView.dequeueReusableCellWithType(TitleSubtitleSwitchTableViewCell.self)!

            cell.bind(viewModel: item)
            cell.delegate = self

            return cell

        case 1:
            let item = viewModel.sortModel.cellViewModels[indexPath.row]
            let cell = tableView.dequeueReusableCellWithType(ValidatorListFilterSortCell.self)!

            cell.bind(viewModel: item)
            return cell

        default:
            return UITableViewCell()
        }
    }
}

// MARK: - UITableViewDelegate

extension ValidatorListFilterViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()

        switch section {
        case 0:
            let title = viewModel?.filterModel.title ?? ""
            view.bind(title: title, icon: nil)

            view.contentInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)
        case 1:
            let title = viewModel?.sortModel.title ?? ""
            view.bind(title: title, icon: nil)

            view.contentInsets = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 8.0, right: 0.0)
        default:
            break
        }

        return view
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 48.0 : 55.0
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else { return }

        presenter.selectFilterItem(at: indexPath.row)
    }
}

// MARK: - SwitchTableViewCellDelegate

extension ValidatorListFilterViewController: SwitchTableViewCellDelegate {
    func didToggle(cell: SwitchTableViewCell) {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return
        }

        presenter.toggleFilterItem(at: indexPath.row)
    }
}

// MARK: - ValidatorListFilterViewProtocol

extension ValidatorListFilterViewController: ValidatorListFilterViewProtocol {
    func didUpdateViewModel(_ viewModel: ValidatorListFilterViewModel) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()
        updateActionButtons()
    }
}

// MARK: - Localizable

extension ValidatorListFilterViewController: Localizable {
    func applyLocalization() {
        title = R.string.localizable
            .walletFiltersTitle(preferredLanguages: selectedLocale.rLanguages)

        navigationItem.rightBarButtonItem?.title = R.string.localizable
            .commonReset(preferredLanguages: selectedLocale.rLanguages)

        rootView.applyButton.imageWithTitleView?.title = R.string.localizable
            .commonApply(preferredLanguages: selectedLocale.rLanguages)

        rootView.tableView.reloadData()
    }
}

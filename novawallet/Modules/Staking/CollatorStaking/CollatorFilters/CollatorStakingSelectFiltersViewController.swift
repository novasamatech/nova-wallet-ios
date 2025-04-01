import UIKit
import Foundation_iOS

final class CollatorStakingSelectFiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = ValidatorListFilterViewLayout

    let presenter: CollatorStakingSelectFiltersPresenterProtocol

    private var viewModel: CollatorStakingSelectFiltersViewModel?

    init(
        presenter: CollatorStakingSelectFiltersPresenterProtocol,
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
        view = ValidatorListFilterViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupResetButton()
        setupApplyButton()
        updateActionButtons()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.tabbarSettingsTitle(preferredLanguages: selectedLocale.rLanguages)

        navigationItem.rightBarButtonItem?.title = R.string.localizable.commonReset(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.applyButton.imageWithTitleView?.title = R.string.localizable.commonApply(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupTableView() {
        rootView.tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)
        rootView.tableView.registerClassForCell(ValidatorListFilterSortCell.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.tableView.separatorStyle = .none
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

    @objc
    func didTapApplyButton() {
        presenter.applyFilter()
    }

    @objc
    func didTapResetButton() {
        presenter.resetFilter()
    }
}

extension CollatorStakingSelectFiltersViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.sorting.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else { return UITableViewCell() }

        let item = viewModel.sorting[indexPath.row]
        let cell = tableView.dequeueReusableCellWithType(ValidatorListFilterSortCell.self)!

        cell.bind(viewModel: item)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension CollatorStakingSelectFiltersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let view: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()

        let title = R.string.localizable.commonFilterSortHeader(
            preferredLanguages: selectedLocale.rLanguages
        )

        view.bind(title: title, icon: nil)

        view.contentInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)

        return view
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        48.0
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.selectSorting(at: indexPath.row)
    }
}

extension CollatorStakingSelectFiltersViewController: CollatorStakingSelectFiltersViewProtocol {
    func didReceive(viewModel: CollatorStakingSelectFiltersViewModel) {
        self.viewModel = viewModel

        updateActionButtons()

        rootView.tableView.reloadData()
    }
}

extension CollatorStakingSelectFiltersViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

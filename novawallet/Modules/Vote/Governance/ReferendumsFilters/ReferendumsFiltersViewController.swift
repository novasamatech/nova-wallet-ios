import UIKit
import Foundation_iOS

final class ReferendumsFiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumsFiltersViewLayout

    let presenter: ReferendumsFiltersPresenterProtocol
    private var viewModel: ReferendumsFilterViewModel?

    init(
        presenter: ReferendumsFiltersPresenterProtocol,
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
        view = ReferendumsFiltersViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupResetButton()
        setupApplyButton()
        setupTableView()
        applyLocalization()

        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)
        rootView.tableView.registerClassForCell(SelectableFilterCell.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.tableView.separatorInset = UIEdgeInsets(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )
    }

    private func setupResetButton() {
        let resetButton = UIBarButtonItem(
            title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonReset(),
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
    private func didTapApplyButton() {
        presenter.applyFilter()
    }

    @objc
    private func didTapResetButton() {
        presenter.resetFilter()
    }
}

extension ReferendumsFiltersViewController: ReferendumsFiltersViewProtocol {
    func didReceive(viewModel: ReferendumsFilterViewModel) {
        guard self.viewModel != viewModel else {
            return
        }

        self.viewModel = viewModel
        updateActionButtons()
        rootView.tableView.reloadData()
    }
}

extension ReferendumsFiltersViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SelectableFilterCell = tableView.dequeueReusableCell(for: indexPath)
        guard let selectedFilter = ReferendumsFilter(rawValue: indexPath.row) else {
            return cell
        }

        cell.bind(viewModel: .init(
            underlyingViewModel: selectedFilter.name.value(for: selectedLocale),
            selectable: viewModel?.selectedFilter == selectedFilter
        ))

        return cell
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        ReferendumsFilter.allCases.count
    }
}

extension ReferendumsFiltersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let view: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
        let header = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.governanceReferendumsFilterHeader()
        view.bind(title: header, icon: nil)
        view.contentInsets = UIEdgeInsets(top: 24, left: 0, bottom: 8, right: 0)
        return view
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        52
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectedFilter = ReferendumsFilter.allCases[safe: indexPath.row] else {
            return
        }

        presenter.select(filter: selectedFilter)
    }
}

extension ReferendumsFiltersViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else {
            return
        }

        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.governanceReferendumsFilterTitle()

        navigationItem.rightBarButtonItem?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonReset()

        rootView.applyButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonApply()

        rootView.tableView.reloadData()
    }
}

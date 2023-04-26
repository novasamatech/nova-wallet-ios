import UIKit
import SoraFoundation

final class ReferendumsFiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumsFiltersViewLayout

    let presenter: ReferendumsFiltersPresenterProtocol

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

    // MARK: - Private functions

    private func setupTableView() {
        rootView.tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)
        rootView.tableView.registerClassForCell(ListFilterCell.self)

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

    private var viewModel: ReferendumsFilterViewModel?
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
        let cell: ListFilterCell = tableView.dequeueReusableCell(for: indexPath)

        switch ReferendumsFilter(rawValue: indexPath.row) {
        case .notVoted:
            cell.bind(viewModel: .init(
                underlyingViewModel: "",
                selectable: viewModel?.selectedFilter == .notVoted
            ))
        case .voted:
            cell.bind(viewModel: .init(
                underlyingViewModel: "",
                selectable: viewModel?.selectedFilter == .voted
            ))
        case .all:
            cell.bind(viewModel: .init(
                underlyingViewModel: "",
                selectable: viewModel?.selectedFilter == .all
            ))
        case .none:
            break
        }

        return cell
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        ReferendumsFilter.allCases.count
    }
}

extension ReferendumsFiltersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let view: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
        let header = viewModel?.header ?? ""
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

        title = R.string.localizable
            .walletFiltersTitle(preferredLanguages: selectedLocale.rLanguages)

        navigationItem.rightBarButtonItem?.title = R.string.localizable
            .commonReset(preferredLanguages: selectedLocale.rLanguages)

        rootView.applyButton.imageWithTitleView?.title = R.string.localizable
            .commonApply(preferredLanguages: selectedLocale.rLanguages)

        rootView.tableView.reloadData()
    }
}

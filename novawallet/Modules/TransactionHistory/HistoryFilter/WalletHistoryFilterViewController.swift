import UIKit
import Foundation_iOS

final class WalletHistoryFilterViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletHistoryFilterViewLayout

    let presenter: WalletHistoryFilterPresenterProtocol

    private var viewModel: WalletHistoryFilterViewModel?

    init(
        presenter: WalletHistoryFilterPresenterProtocol,
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
        view = WalletHistoryFilterViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupTableView()
        setupApplyButton()
        setupLocalization()

        presenter.setup()
    }

    private func setupApplyButton() {
        rootView.applyButton.addTarget(self, action: #selector(actionApply), for: .touchUpInside)
    }

    private func setupNavigationItem() {
        let resetItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(actionReset)
        )

        resetItem.setupDefaultTitleStyle(with: .regularBody)

        navigationItem.rightBarButtonItem = resetItem
    }

    private func setupTableView() {
        rootView.tableView.registerClassForCell(SwitchTableViewCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.tableView.rowHeight = 48.0
        rootView.tableView.separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
    }

    private func setupLocalization() {
        let languages = localizationManager?.selectedLocale.rLanguages

        title = R.string.localizable.walletFiltersTitle(preferredLanguages: languages)
        navigationItem.rightBarButtonItem?.title = R.string.localizable
            .commonReset(preferredLanguages: languages)

        rootView.applyButton.imageWithTitleView?.title = R.string.localizable
            .commonApply(preferredLanguages: languages)
        rootView.applyButton.invalidateLayout()
    }

    private func updateActionsState() {
        let isEnabled = viewModel?.canApply ?? false
        rootView.applyButton.set(enabled: isEnabled)
        navigationItem.rightBarButtonItem?.isEnabled = viewModel?.canReset ?? false
    }

    @objc private func actionReset() {
        presenter.reset()
    }

    @objc private func actionApply() {
        presenter.apply()
    }
}

extension WalletHistoryFilterViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.items.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let items = viewModel?.items ?? []

        let cell = tableView.dequeueReusableCellWithType(SwitchTableViewCell.self)!
        cell.delegate = self

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let title = items[indexPath.row].title.value(for: locale)
        let isOn = items[indexPath.row].isOn

        cell.bind(title: title, isOn: isOn)

        return cell
    }
}

extension WalletHistoryFilterViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let view: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()

        let title = R.string.localizable.walletFiltersHeader(
            preferredLanguages: selectedLocale.rLanguages
        )

        view.bind(title: title, icon: nil)

        return view
    }
}

extension WalletHistoryFilterViewController: SwitchTableViewCellDelegate {
    func didToggle(cell: SwitchTableViewCell) {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return
        }

        presenter.toggleFilterItem(at: indexPath.row)
    }
}

extension WalletHistoryFilterViewController: WalletHistoryFilterViewProtocol {
    func didReceive(viewModel: WalletHistoryFilterViewModel) {
        self.viewModel = viewModel

        rootView.tableView.reloadData()

        updateActionsState()
    }

    func didConfirm(viewModel: WalletHistoryFilterViewModel) {
        self.viewModel = viewModel

        updateActionsState()
    }
}

extension WalletHistoryFilterViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.tableView.reloadData()
        }
    }
}

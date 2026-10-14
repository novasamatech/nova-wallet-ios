import Foundation_iOS
import UIKit

final class SubtensorValidatorSelectViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorValidatorSelectViewLayout

    let presenter: ValidatorSelectPresenterProtocol

    private var state: SubtensorValidatorListState?

    init(presenter: ValidatorSelectPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorValidatorSelectViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupHandlers()
        setupNavigationItems()
        setupLocalization()

        presenter.setup()
    }
}

private extension SubtensorValidatorSelectViewController {
    static let loadingRowsCount = 6

    var loadedViewModel: SubtensorValidatorListViewModel? {
        if case let .loaded(viewModel) = state {
            return viewModel
        }

        return nil
    }

    var isLoading: Bool {
        if case .loading = state {
            return true
        }

        return false
    }

    func setupTableView() {
        rootView.tableView.registerClassForCell(SubtensorValidatorSelectCell.self)
        rootView.tableView.registerClassForCell(SubtensorValidatorSkeletonCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: SubtensorValidatorSectionHeaderView.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    func setupHandlers() {
        rootView.searchField.addTarget(self, action: #selector(actionSearchChanged), for: .editingChanged)
        rootView.actionButton.addTarget(self, action: #selector(actionConfirm), for: .touchUpInside)

        rootView.errorView.onLinkTap = { [weak self] in
            self?.presenter.retry()
        }
    }

    func setupNavigationItems() {
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: R.image.iconFilter(),
                style: .plain,
                target: self,
                action: #selector(actionSort)
            ),
            UIBarButtonItem(
                image: R.image.iconSearch(),
                style: .plain,
                target: self,
                action: #selector(actionToggleSearch)
            )
        ]
    }

    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        title = strings.stakingSubtensorSelectValidator()
        rootView.searchField.placeholder = strings.stakingSubtensorUiValidatorSearch()
    }

    func applyState() {
        guard let state else {
            return
        }

        switch state {
        case let .loading(viewModel):
            rootView.bindAction(title: viewModel.selectTitle, isEnabled: false)
            rootView.emptyLabel.isHidden = true
            rootView.errorView.isHidden = true
            rootView.tableView.isHidden = false
        case let .loaded(viewModel):
            rootView.headerView.bind(title: viewModel.countTitle, details: viewModel.sortTitle)
            rootView.bindAction(title: viewModel.selectTitle, isEnabled: viewModel.canSelect)
            rootView.emptyLabel.text = viewModel.emptyText
            rootView.emptyLabel.isHidden = viewModel.emptyText == nil
            rootView.errorView.isHidden = true
            rootView.tableView.isHidden = false
        case let .failed(viewModel):
            rootView.bindAction(title: viewModel.selectTitle, isEnabled: false)
            rootView.bindError(viewModel)
            rootView.emptyLabel.isHidden = true
            rootView.errorView.isHidden = false
            rootView.tableView.isHidden = true
        }

        rootView.tableView.reloadData()
    }

    func rowModel(at indexPath: IndexPath) -> SubtensorValidatorRowViewModel? {
        guard let viewModel = loadedViewModel, viewModel.rows.indices.contains(indexPath.row) else {
            return nil
        }

        return viewModel.rows[indexPath.row]
    }

    @objc func actionSearchChanged() {
        presenter.search(rootView.searchField.text ?? "")
    }

    @objc func actionConfirm() {
        presenter.confirm()
    }

    @objc func actionSort() {
        presenter.showSortOptions()
    }

    @objc func actionToggleSearch() {
        let isVisible = rootView.searchField.isHidden

        rootView.setSearchVisible(isVisible)

        if isVisible {
            rootView.searchField.becomeFirstResponder()
        } else {
            rootView.searchField.resignFirstResponder()
            rootView.searchField.text = nil
            presenter.search("")
        }
    }
}

extension SubtensorValidatorSelectViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        if isLoading {
            return Self.loadingRowsCount
        }

        return loadedViewModel?.rows.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let model = rowModel(at: indexPath) else {
            return tableView.dequeueReusableCellWithType(SubtensorValidatorSkeletonCell.self, forIndexPath: indexPath)
        }

        let cell = tableView.dequeueReusableCellWithType(SubtensorValidatorSelectCell.self, forIndexPath: indexPath)

        cell.bind(model)

        cell.infoAction = { [weak self] in
            self?.presenter.showInfo(hotkey: model.hotkey)
        }

        return cell
    }
}

extension SubtensorValidatorSelectViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat { 0 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let model = rowModel(at: indexPath) else {
            return
        }

        presenter.select(hotkey: model.hotkey)
    }
}

extension SubtensorValidatorSelectViewController: SubtensorValidatorSelectViewProtocol {
    func didReceive(header: SubtensorValidatorListHeaderViewModel, isFilterActive: Bool) {
        rootView.headerView.bind(title: header.countTitle, details: header.sortTitle)
        navigationItem.rightBarButtonItems?.first?.tintColor = isFilterActive
            ? R.color.colorButtonBackgroundPrimary() : R.color.colorIconPrimary()
    }

    func didReceive(state: SubtensorValidatorListState) {
        self.state = state

        applyState()
    }
}

extension SubtensorValidatorSelectViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

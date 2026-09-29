import Foundation_iOS
import SubstrateSdk
import UIKit

final class SubtensorValidatorSelectViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorValidatorSelectViewLayout

    let presenter: ValidatorSelectPresenterProtocol

    private let iconGenerator = PolkadotIconGenerator()
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
    enum Section: Int, CaseIterable {
        case recommended
        case validators
    }

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
        guard let viewModel = loadedViewModel, let section = Section(rawValue: indexPath.section) else {
            return nil
        }

        switch section {
        case .recommended:
            return viewModel.recommended
        case .validators:
            return viewModel.rows.indices.contains(indexPath.row) ? viewModel.rows[indexPath.row] : nil
        }
    }

    func hasHeader(for section: Section) -> Bool {
        switch section {
        case .recommended:
            return isLoading || loadedViewModel?.recommended != nil
        case .validators:
            return isLoading || (loadedViewModel.map { !$0.rows.isEmpty || $0.recommended != nil } ?? false)
        }
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
    func numberOfSections(in _: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }

        if isLoading {
            return section == .recommended ? 1 : Self.loadingRowsCount
        }

        guard let viewModel = loadedViewModel else {
            return 0
        }

        switch section {
        case .recommended:
            return viewModel.recommended != nil ? 1 : 0
        case .validators:
            return viewModel.rows.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let model = rowModel(at: indexPath) else {
            return tableView.dequeueReusableCellWithType(SubtensorValidatorSkeletonCell.self, forIndexPath: indexPath)
        }

        let cell = tableView.dequeueReusableCellWithType(SubtensorValidatorSelectCell.self, forIndexPath: indexPath)

        cell.bind(
            model,
            icon: try? iconGenerator.generateFromAccountId(model.hotkey),
            recommendedTitle: R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorUiValidatorRecommended()
        )

        cell.infoAction = { [weak self] in
            self?.presenter.showInfo(hotkey: model.hotkey)
        }

        return cell
    }
}

extension SubtensorValidatorSelectViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let section = Section(rawValue: section), hasHeader(for: section) else {
            return 0
        }

        return rootView.tableView.sectionHeaderHeight
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let section = Section(rawValue: section), hasHeader(for: section) else {
            return nil
        }

        let header: SubtensorValidatorSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        switch (section, state) {
        case (.recommended, _):
            header.bind(title: strings.stakingSubtensorUiValidatorRecommended(), details: nil)
        case let (.validators, .loading(viewModel)):
            header.bind(title: viewModel.countTitle, details: viewModel.sortTitle)
        case let (.validators, .loaded(viewModel)):
            header.bind(title: viewModel.countTitle, details: viewModel.sortTitle)
        case (.validators, _):
            header.bind(title: strings.stakingSubtensorUiValidatorLoadingCount(), details: nil)
        }

        return header
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let model = rowModel(at: indexPath), model.isSelectable else {
            return
        }

        presenter.select(hotkey: model.hotkey)
    }
}

extension SubtensorValidatorSelectViewController: SubtensorValidatorSelectViewProtocol {
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

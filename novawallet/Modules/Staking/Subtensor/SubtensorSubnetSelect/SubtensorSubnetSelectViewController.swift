import Foundation_iOS
import UIKit

final class SubtensorSubnetSelectViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorSubnetSelectViewLayout

    let presenter: SubtensorSubnetSelectPresenterProtocol

    private var viewModel: SubtensorSubnetListViewModel?

    init(
        presenter: SubtensorSubnetSelectPresenterProtocol,
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
        view = SubtensorSubnetSelectViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        presenter.becomeActive()
    }
}

private extension SubtensorSubnetSelectViewController {
    enum Section: Int, CaseIterable {
        case root
        case picks
        case others
    }

    static let loadingRowsCount = 8
    static let rootSpacing: CGFloat = 8

    var isLoading: Bool {
        guard let viewModel else {
            return true
        }

        if case .loading = viewModel.content {
            return true
        }

        return false
    }

    func rows(for section: Section) -> [SubtensorSubnetSelectViewModel] {
        guard case let .rows(picks, others) = viewModel?.content else {
            return []
        }

        switch section {
        case .root: return []
        case .picks:
            return picks
        case .others:
            return others
        }
    }

    func rowModel(at indexPath: IndexPath) -> SubtensorSubnetSelectViewModel? {
        guard !isLoading, let section = Section(rawValue: indexPath.section) else {
            return nil
        }

        let rows = rows(for: section)

        return rows.indices.contains(indexPath.row) ? rows[indexPath.row] : nil
    }

    func setupTableView() {
        rootView.tableView.registerClassForCell(SubtensorSubnetCell.self)
        rootView.tableView.registerClassForCell(SubtensorSubnetSkeletonCell.self)
        rootView.tableView.registerClassForCell(SubtensorSubnetRootCell.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    func setupHandlers() {
        rootView.searchTextField.addTarget(self, action: #selector(actionSearchChanged), for: .editingChanged)
        rootView.sortView.control.addTarget(self, action: #selector(actionSort), for: .touchUpInside)
        rootView.filterButton.addTarget(self, action: #selector(actionFilters), for: .touchUpInside)
        rootView.errorView.onLinkTap = { [weak self] in
            self?.presenter.retry()
        }
    }

    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        title = strings.stakingSubtensorSubnetSelectTitle()

        rootView.searchTextField.attributedPlaceholder = NSAttributedString(
            string: strings.stakingSubtensorSubnetSearchPlaceholder(),
            attributes: [.foregroundColor: R.color.colorHintText()!]
        )

        rootView.filterButton.accessibilityLabel = strings.walletFiltersTitle()

        rootView.tableView.reloadData()
    }

    func applyViewModel() {
        guard let viewModel else {
            return
        }

        rootView.bind(controls: viewModel)

        switch viewModel.content {
        case let .empty(text), let .noMatches(text):
            rootView.bind(emptyText: text)
        default:
            rootView.bind(emptyText: nil)
        }

        if case let .failed(failure) = viewModel.content {
            rootView.bind(failure: failure)
        } else {
            rootView.bind(failure: nil)
        }

        rootView.tableView.reloadData()
    }

    @objc func actionSearchChanged() {
        presenter.search(query: rootView.searchTextField.text ?? "")
    }

    @objc func actionSort() {
        presenter.showSort()
    }

    @objc func actionFilters() {
        presenter.showFilters()
    }

    @objc func actionRoot() {
        presenter.selectRoot()
    }
}

extension SubtensorSubnetSelectViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }

        if section == .root { return viewModel?.isNoMatches == true ? 0 : 1 }

        if isLoading {
            return section == .others ? Self.loadingRowsCount : 0
        }

        return rows(for: section).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == Section.root.rawValue {
            let cell = tableView.dequeueReusableCellWithType(SubtensorSubnetRootCell.self, forIndexPath: indexPath)
            let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
            cell.bind(title: strings.stakingSubtensorUiStakeToRoot(), icon: viewModel?.rootIcon)
            return cell
        }

        guard let model = rowModel(at: indexPath) else {
            return tableView.dequeueReusableCellWithType(SubtensorSubnetSkeletonCell.self, forIndexPath: indexPath)
        }

        let cell = tableView.dequeueReusableCellWithType(SubtensorSubnetCell.self, forIndexPath: indexPath)

        cell.bind(viewModel: model)

        cell.favoriteAction = { [weak self] in
            self?.presenter.toggleFavorite(model.subnetRef)
        }

        return cell
    }
}

extension SubtensorSubnetSelectViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat { .leastNormalMagnitude }

    func tableView(_: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == Section.root.rawValue ? Self.rootSpacing : 0
    }

    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        UIView()
    }

    func tableView(_: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == Section.root.rawValue || rowModel(at: indexPath) != nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == Section.root.rawValue {
            presenter.selectRoot()
            return
        }
        guard let model = rowModel(at: indexPath) else { return }

        presenter.selectSubnet(model.subnetRef)
    }
}

extension SubtensorSubnetSelectViewController: SubtensorSubnetSelectViewProtocol {
    func didReceive(list: SubtensorSubnetListViewModel) {
        viewModel = list

        applyViewModel()
    }
}

extension SubtensorSubnetSelectViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

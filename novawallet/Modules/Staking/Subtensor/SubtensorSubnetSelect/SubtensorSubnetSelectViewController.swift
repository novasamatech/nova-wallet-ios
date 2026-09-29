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
        case picks
        case others
    }

    static let loadingRowsCount = 8
    static let picksSpacing: CGFloat = 12

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
        rootView.tableView.registerHeaderFooterView(withClass: SubtensorSubnetPicksHeaderView.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    func setupHandlers() {
        rootView.searchTextField.addTarget(self, action: #selector(actionSearchChanged), for: .editingChanged)
        rootView.sortView.control.addTarget(self, action: #selector(actionSort), for: .touchUpInside)
        rootView.filterButton.addTarget(self, action: #selector(actionFilters), for: .touchUpInside)
        rootView.rootBarView.addTarget(self, action: #selector(actionRoot), for: .touchUpInside)
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

        if case let .empty(text) = viewModel.content {
            rootView.bind(emptyText: text)
        } else {
            rootView.bind(emptyText: nil)
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

        if isLoading {
            return section == .others ? Self.loadingRowsCount : 0
        }

        return rows(for: section).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == Section.picks.rawValue && !rows(for: .picks).isEmpty
            ? SubtensorSubnetPicksHeaderView.preferredHeight
            : 0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == Section.picks.rawValue, !rows(for: .picks).isEmpty else {
            return nil
        }

        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        let header: SubtensorSubnetPicksHeaderView = tableView.dequeueReusableHeaderFooterView()

        header.bind(
            title: strings.stakingSubtensorUiPickerPicksHeader(),
            caption: strings.stakingSubtensorUiPickerPicksCaption()
        )

        return header
    }

    func tableView(_: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == Section.picks.rawValue && !rows(for: .picks).isEmpty && !rows(for: .others).isEmpty
            ? Self.picksSpacing
            : 0
    }

    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        UIView()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let model = rowModel(at: indexPath) else {
            return
        }

        presenter.selectSubnet(model.subnetRef)
    }
}

extension SubtensorSubnetSelectViewController: SubtensorSubnetSelectViewProtocol {
    func didReceive(list: SubtensorSubnetListViewModel) {
        viewModel = list

        applyViewModel()
    }

    func didReceive(rootBar: SubtensorStakeToRootBarViewModel) {
        rootView.rootBarView.bind(viewModel: rootBar)
    }
}

extension SubtensorSubnetSelectViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

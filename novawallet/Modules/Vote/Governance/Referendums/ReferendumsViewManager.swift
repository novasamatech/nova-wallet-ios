import Foundation
import UIKit

final class ReferendumsViewManager: NSObject {
    private enum Constants {
        static let singleActivityCellHeight: CGFloat = 52
        static let firstOrLastActivityCellHeight: CGFloat = 50
        static let swipeGovBannerHeight: CGFloat = 102
        static let referendumCellMinimumHeight: CGFloat = 185
        static let headerMinimumHeight: CGFloat = 56
        static let settingsCellHeight: CGFloat = 32
    }

    let tableView: UITableView
    let chainSelectionView: VoteChainViewProtocol
    private var referendumsViewModel: ReferendumsViewModel = .init(sections: [])

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                tableView.reloadData()
            }
        }
    }

    weak var presenter: ReferendumsPresenterProtocol?
    private weak var parent: ControllerBackedProtocol?

    init(tableView: UITableView, chainSelectionView: VoteChainViewProtocol, parent: ControllerBackedProtocol) {
        self.tableView = tableView
        self.chainSelectionView = chainSelectionView
        self.parent = parent

        super.init()
    }
}

extension ReferendumsViewManager: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        referendumsViewModel.sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch referendumsViewModel.sections[section] {
        case let .personalActivities(actions):
            return actions.count
        case .settings, .swipeGov, .empty:
            return 1
        case let .active(_, cells), let .completed(_, cells):
            return !cells.isEmpty ? cells.count : 1
        }
    }

    func personalActivityCell(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath,
        activity: ReferendumPersonalActivity,
        totalActivities: Int
    ) -> UITableViewCell {
        switch activity {
        case let .locks(unlocksViewModel):
            let unlocksCell: ReferendumsUnlocksTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            unlocksCell.applyStyle(for: totalActivities > 1 ? .top : .single)
            unlocksCell.view.bind(viewModel: unlocksViewModel, locale: locale)
            return unlocksCell
        case let .delegations(delegationsViewModel):
            let delegationCell: ReferendumsDelegationsTableViewCell =
                tableView.dequeueReusableCell(for: indexPath)
            delegationCell.applyStyle(for: totalActivities > 1 ? .bottom : .single)
            delegationCell.view.bind(viewModel: delegationsViewModel, locale: locale)
            return delegationCell
        }
    }

    func swipeGovBannerCell(
        _ tableView: UITableView,
        viewModel: SwipeGovBannerViewModel,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell: SwipeGovBannerTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.contentDisplayView.bind(with: viewModel)
        cell.setupStyle()

        return cell
    }

    func referendumCell(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath,
        items: [ReferendumsCellViewModel]
    ) -> UITableViewCell {
        let cell: ReferendumTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.applyStyle()
        let cellModel = items[indexPath.row].viewModel
        cell.view.bind(viewModel: cellModel)
        return cell
    }

    func emptyCell(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath,
        emptyModel: ReferendumsEmptyModel
    ) -> UITableViewCell {
        let cell: ReferendumEmptySearchTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        let text: String
        let image: UIImage?

        switch emptyModel {
        case .referendumsNotFound:
            text = R.string.localizable.govEmptyList(preferredLanguages: locale.rLanguages)
            image = R.image.iconEmptyHistory()
        case .filteredListEmpty:
            text = R.string.localizable.governanceReferendumsFilterEmpty(preferredLanguages: locale.rLanguages)
            image = R.image.iconEmptySearch()?
                .withRenderingMode(.alwaysTemplate)
                .tinted(with: R.color.colorIconSecondary()!)
        }

        cell.bind(text: text)
        cell.bind(icon: image)

        return cell
    }

    func settingsCell(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath,
        isFilterOn: Bool
    ) -> UITableViewCell {
        let settingsCell: ReferendumsSettingsCell = tableView.dequeueReusableCell(for: indexPath)
        let title = R.string.localizable.governanceReferendumsSettingsTitle(preferredLanguages: locale.rLanguages)
        settingsCell.bind(title: title, isFilterOn: isFilterOn)
        settingsCell.filterButton.addTarget(self, action: #selector(filterAction), for: .touchUpInside)
        settingsCell.searchButton.addTarget(self, action: #selector(searchAction), for: .touchUpInside)
        settingsCell.selectionStyle = .none
        return settingsCell
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = referendumsViewModel.sections[indexPath.section]

        switch section {
        case let .personalActivities(personalActivities):
            let activity = personalActivities[indexPath.row]
            return personalActivityCell(
                tableView,
                cellForRowAt: indexPath,
                activity: activity,
                totalActivities: personalActivities.count
            )
        case let .swipeGov(viewModel):
            return swipeGovBannerCell(
                tableView,
                viewModel: viewModel,
                cellForRowAt: indexPath
            )
        case let .settings(isFilterOn):
            return settingsCell(
                tableView,
                cellForRowAt: indexPath,
                isFilterOn: isFilterOn
            )
        case let .active(_, cells), let .completed(_, cells):
            return referendumCell(tableView, cellForRowAt: indexPath, items: cells)
        case let .empty(model):
            return emptyCell(tableView, cellForRowAt: indexPath, emptyModel: model)
        }
    }

    @objc
    private func filterAction() {
        presenter?.showFilters()
    }

    @objc
    private func searchAction() {
        presenter?.showSearch()
    }
}

extension ReferendumsViewManager: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let section = referendumsViewModel.sections[indexPath.section]

        switch section {
        case let .personalActivities(actions):
            let action = actions[indexPath.row]
            switch action {
            case .locks:
                presenter?.selectUnlocks()
            case .delegations:
                presenter?.selectDelegations()
            }
        case .swipeGov:
            presenter?.selectSwipeGov()
        case .settings, .empty:
            break
        case let .active(_, cells), let .completed(_, cells):
            guard let referendumIndex = cells[safe: indexPath.row]?.referendumIndex else {
                return
            }
            presenter?.select(referendumIndex: referendumIndex)
        }
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = referendumsViewModel.sections[section]

        switch section {
        case .personalActivities, .swipeGov, .settings, .empty:
            return nil
        case let .active(title, cells), let .completed(title, cells):
            let headerView: VoteStatusSectionView = tableView.dequeueReusableHeaderFooterView()
            switch title {
            case let .loaded(value):
                headerView.bind(viewModel: .loaded(value: .init(title: value, count: cells.count)))
            case let .cached(value):
                headerView.bind(viewModel: .cached(value: .init(title: value, count: cells.count)))
            case .loading:
                headerView.bind(viewModel: .loading)
            }
            return headerView
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let section = referendumsViewModel.sections[section]

        switch section {
        case .personalActivities, .swipeGov, .settings, .empty:
            return 0
        case let .active(title, _), let .completed(title, _):
            switch title {
            case .loaded, .cached:
                return UITableView.automaticDimension
            case .loading:
                return Constants.headerMinimumHeight
            }
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = referendumsViewModel.sections[indexPath.section]

        switch section {
        case let .personalActivities(activities):
            return activities.count > 1 ? Constants.firstOrLastActivityCellHeight : Constants.singleActivityCellHeight
        case .swipeGov:
            return Constants.swipeGovBannerHeight
        case .settings:
            return Constants.settingsCellHeight
        case let .active(_, cells), let .completed(_, cells):
            switch cells[safe: indexPath.row]?.viewModel {
            case .loaded, .cached, .none:
                return UITableView.automaticDimension
            case .loading:
                return Constants.referendumCellMinimumHeight
            }
        case .empty:
            return UITableView.automaticDimension
        }
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt _: IndexPath) {
        (cell as? SkeletonableViewCell)?.updateLoadingState()
    }

    func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection _: Int) {
        (view as? SkeletonableView)?.updateLoadingState()
    }
}

extension ReferendumsViewManager: ReferendumsViewProtocol {
    func didReceiveChainBalance(viewModel: ChainBalanceViewModel) {
        chainSelectionView.bind(viewModel: viewModel)
    }

    func update(model: ReferendumsViewModel) {
        referendumsViewModel = model
        tableView.reloadData()
    }

    func updateReferendums(time: [ReferendumIdLocal: StatusTimeViewModel?]) {
        tableView.visibleCells.forEach { cell in
            guard let referendumCell = cell as? ReferendumTableViewCell,
                  let indexPath = tableView.indexPath(for: cell) else {
                return
            }
            let section = referendumsViewModel.sections[indexPath.section]

            switch section {
            case .personalActivities, .swipeGov, .settings, .empty:
                break
            case let .active(_, cells), let .completed(_, cells):
                let cellModel = cells[indexPath.row]
                guard let timeModel = time[cellModel.referendumIndex]??.viewModel else {
                    return
                }

                referendumCell.view.referendumInfoView.bind(timeModel: timeModel)
            }
        }
    }
}

extension ReferendumsViewManager: VoteChildViewProtocol {
    var isSetup: Bool {
        parent?.isSetup ?? false
    }

    var controller: UIViewController {
        parent?.controller ?? UIViewController()
    }

    func bind() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerClassForCell(ReferendumTableViewCell.self)
        tableView.registerClassForCell(ReferendumsUnlocksTableViewCell.self)
        tableView.registerClassForCell(ReferendumsDelegationsTableViewCell.self)
        tableView.registerClassForCell(SwipeGovBannerTableViewCell.self)
        tableView.registerClassForCell(ReferendumEmptySearchTableViewCell.self)
        tableView.registerClassForCell(ReferendumsSettingsCell.self)
        tableView.registerHeaderFooterView(withClass: VoteStatusSectionView.self)
        tableView.reloadData()
    }

    func unbind() {
        tableView.dataSource = nil
        tableView.delegate = nil
        tableView.unregisterClassForCell(ReferendumTableViewCell.self)
        tableView.unregisterClassForCell(ReferendumsUnlocksTableViewCell.self)
        tableView.unregisterClassForCell(ReferendumsDelegationsTableViewCell.self)
        tableView.unregisterClassForCell(SwipeGovBannerTableViewCell.self)
        tableView.unregisterClassForCell(ReferendumEmptySearchTableViewCell.self)
        tableView.unregisterClassForCell(ReferendumsSettingsCell.self)
        tableView.unregisterHeaderFooterView(withClass: VoteStatusSectionView.self)
        tableView.reloadData()
    }
}

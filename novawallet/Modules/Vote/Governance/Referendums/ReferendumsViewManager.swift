import Foundation
import UIKit

final class ReferendumsViewManager: NSObject {
    private enum Constants {
        static let unlocksCellHeight: CGFloat = 52
        static let referendumCellMinimumHeight: CGFloat = 185
        static let headerMinimumHeight: CGFloat = 56
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
        case let .actions(actions):
            return actions.count
        case let .active(_, cells), let .completed(_, cells):
            return !cells.isEmpty ? cells.count : 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = referendumsViewModel.sections[indexPath.section]

        switch section {
        case let .actions(actions):
            let action = actions[indexPath.row]
            switch action {
            case let .locks(unlocksViewModel):
                let unlocksCell: ReferendumsUnlocksTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                unlocksCell.applyStyle()
                unlocksCell.view.bind(viewModel: unlocksViewModel, locale: locale)
                return unlocksCell
            case .delegations:
                let delegationCell: ReferendumsUnlocksTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                delegationCell.applyStyle()
                delegationCell.view.titleLabel.text = "Add Delegation"
                return delegationCell
            }
        case let .active(_, cells), let .completed(_, cells):
            if cells.isEmpty {
                let cell: BlurredTableViewCell<CrowdloanEmptyView> = tableView.dequeueReusableCell(for: indexPath)
                let text = R.string.localizable.govEmptyList(preferredLanguages: locale.rLanguages)
                cell.view.bind(image: R.image.iconEmptyHistory(), text: text)
                cell.applyStyle()

                return cell
            } else {
                let cell: ReferendumTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.applyStyle()
                let cellModel = cells[indexPath.row].viewModel
                cell.view.bind(viewModel: cellModel)
                return cell
            }
        }
    }
}

extension ReferendumsViewManager: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let section = referendumsViewModel.sections[indexPath.section]

        switch section {
        case let .actions(actions):
            let action = actions[indexPath.row]
            switch action {
            case .locks:
                presenter?.selectUnlocks()
            case .delegations:
                presenter?.selectDelegations()
            }
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
        case .actions:
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
        case .actions:
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
        case .actions:
            return Constants.unlocksCellHeight
        case let .active(_, cells), let .completed(_, cells):
            switch cells[safe: indexPath.row]?.viewModel {
            case .loaded, .cached, .none:
                return UITableView.automaticDimension
            case .loading:
                return Constants.referendumCellMinimumHeight
            }
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

    func updateReferendums(time: [UInt: StatusTimeViewModel?]) {
        tableView.visibleCells.forEach { cell in
            guard let referendumCell = cell as? ReferendumTableViewCell,
                  let indexPath = tableView.indexPath(for: cell) else {
                return
            }
            let section = referendumsViewModel.sections[indexPath.section]

            switch section {
            case .actions:
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
        tableView.registerClassForCell(BlurredTableViewCell<CrowdloanEmptyView>.self)
        tableView.registerHeaderFooterView(withClass: VoteStatusSectionView.self)
        tableView.reloadData()
    }

    func unbind() {
        tableView.dataSource = nil
        tableView.delegate = nil
        tableView.unregisterClassForCell(ReferendumTableViewCell.self)
        tableView.unregisterClassForCell(ReferendumsUnlocksTableViewCell.self)
        tableView.unregisterClassForCell(BlurredTableViewCell<CrowdloanEmptyView>.self)
        tableView.unregisterHeaderFooterView(withClass: VoteStatusSectionView.self)
        tableView.reloadData()
    }
}

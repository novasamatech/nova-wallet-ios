import Foundation
import UIKit

final class ReferendumsViewManager: NSObject {
    private enum Constants {
        static let unlocksCellHeight: CGFloat = 52
        static let referndumCellMinimumHeight: CGFloat = 185
        static let headerMinimumHeight: CGFloat = 56
    }

    let tableView: UITableView
    let chainSelectionView: VoteChainViewProtocol
    private var referendumsViewModel: ReferendumsViewModel = .init(sections: [])
    private var unlocksViewModel: ReferendumsUnlocksViewModel?

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
        referendumsViewModel.sections.count + 1
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return unlocksViewModel != nil ? 1 : 0
        } else {
            let referendumsSection = section - 1
            switch referendumsViewModel.sections[referendumsSection] {
            case let .active(_, cells), let .completed(_, cells):
                return cells.count
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let unlocksCell: ReferendumsUnlocksTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            unlocksCell.applyStyle()

            if let viewModel = unlocksViewModel {
                unlocksCell.view.bind(viewModel: viewModel, locale: locale)
            }

            return unlocksCell
        } else {
            let cell: ReferendumTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.applyStyle()

            let referendumsSection = indexPath.section - 1
            let section = referendumsViewModel.sections[referendumsSection]
            switch section {
            case let .active(_, cellModels), let .completed(_, cellModels):
                let cellModel = cellModels[indexPath.row].viewModel
                cell.view.bind(viewModel: cellModel)
                return cell
            }
        }
    }
}

extension ReferendumsViewManager: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            presenter?.selectUnlocks()
        } else {
            let referendumsSection = indexPath.section - 1
            let section = referendumsViewModel.sections[referendumsSection]
            switch section {
            case let .active(_, cellModels), let .completed(_, cellModels):
                let referendumIndex = cellModels[indexPath.row].referendumIndex
                presenter?.select(referendumIndex: referendumIndex)
            }
        }
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section > 0 else {
            return nil
        }

        let referendumsSection = section - 1
        let sectionModel = referendumsViewModel.sections[referendumsSection]
        switch sectionModel {
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
        guard section > 0 else {
            return 0
        }
        let referendumsSection = section - 1
        let sectionModel = referendumsViewModel.sections[referendumsSection]
        switch sectionModel {
        case let .active(header, _), let .completed(header, _):
            switch header {
            case .loaded, .cached:
                return UITableView.automaticDimension
            case .loading:
                return Constants.headerMinimumHeight
            }
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.section > 0 else {
            return Constants.unlocksCellHeight
        }
        let referendumsSection = indexPath.section - 1
        let sectionModel = referendumsViewModel.sections[referendumsSection]
        switch sectionModel {
        case let .active(_, cells), let .completed(_, cells):
            switch cells[indexPath.row].viewModel {
            case .loaded, .cached:
                return UITableView.automaticDimension
            case .loading:
                return Constants.referndumCellMinimumHeight
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

            let referendumsSection = indexPath.section - 1
            switch referendumsViewModel.sections[referendumsSection] {
            case let .active(_, cells), let .completed(_, cells):
                let cellModel = cells[indexPath.row]
                guard let timeModel = time[cellModel.referendumIndex]??.viewModel else {
                    return
                }

                referendumCell.view.referendumInfoView.bind(timeModel: timeModel)
            }
        }
    }

    func didReceiveUnlocks(viewModel: ReferendumsUnlocksViewModel?) {
        unlocksViewModel = viewModel
        tableView.reloadData()
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
        tableView.registerHeaderFooterView(withClass: VoteStatusSectionView.self)
        tableView.reloadData()
    }

    func unbind() {
        tableView.dataSource = nil
        tableView.delegate = nil
        tableView.unregisterClassForCell(ReferendumTableViewCell.self)
        tableView.unregisterClassForCell(ReferendumsUnlocksTableViewCell.self)
        tableView.unregisterHeaderFooterView(withClass: VoteStatusSectionView.self)
        tableView.reloadData()
    }
}

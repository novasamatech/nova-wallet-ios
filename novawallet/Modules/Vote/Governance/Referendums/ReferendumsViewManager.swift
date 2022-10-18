import Foundation
import UIKit

final class ReferendumsViewManager: NSObject {
    let tableView: UITableView
    let chainSelectionView: VoteChainViewProtocol
    private var model: ReferendumsViewModel = .init(sections: [])

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
        model.sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch model.sections[section] {
        case let .active(_, cells), let .completed(_, cells):
            return cells.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ReferendumTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.applyStyle()
        let section = model.sections[indexPath.section]
        switch section {
        case let .active(_, cellModels), let .completed(_, cellModels):
            let cellModel = cellModels[indexPath.row].viewModel
            cell.view.bind(viewModel: cellModel)
            return cell
        }
    }
}

extension ReferendumsViewManager: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch model.sections[indexPath.section] {
        case let .active(_, cells), let .completed(_, cells):
            presenter?.selectReferendum(referendumIndex: cells[indexPath.row].referendumIndex)
        }
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionModel = model.sections[section]
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

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        UITableView.automaticDimension
    }
}

extension ReferendumsViewManager: ReferendumsViewProtocol {
    func didReceiveChainBalance(viewModel: ChainBalanceViewModel) {
        chainSelectionView.bind(viewModel: viewModel)
    }

    func update(model: ReferendumsViewModel) {
        self.model = model
        tableView.reloadData()
    }

    func updateReferendums(time: [UInt: StatusTimeModel?]) {
        tableView.visibleCells.forEach { cell in
            guard let referendumCell = cell as? ReferendumTableViewCell,
                  let indexPath = tableView.indexPath(for: cell) else {
                return
            }

            switch model.sections[indexPath.section] {
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
        tableView.registerHeaderFooterView(withClass: VoteStatusSectionView.self)
        tableView.reloadData()
    }

    func unbind() {
        tableView.dataSource = nil
        tableView.delegate = nil
        tableView.unregisterClassForCell(ReferendumTableViewCell.self)
        tableView.unregisterHeaderFooterView(withClass: VoteStatusSectionView.self)
        tableView.reloadData()
    }
}

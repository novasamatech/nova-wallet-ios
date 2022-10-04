import Foundation
import UIKit
import SoraFoundation

final class CrowdloanListViewManager: NSObject {
    let tableView: UITableView
    let chainSelectionView: VoteChainViewProtocol

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                tableView.reloadData()
            }
        }
    }

    weak var presenter: CrowdloanListPresenterProtocol?
    private weak var parent: ControllerBackedProtocol?

    private var state: CrowdloanListState = .loading

    init(tableView: UITableView, chainSelectionView: VoteChainViewProtocol, parent: ControllerBackedProtocol) {
        self.tableView = tableView
        self.chainSelectionView = chainSelectionView
        self.parent = parent

        super.init()
    }
}

extension CrowdloanListViewManager: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        switch state {
        case let .loaded(viewModel):
            return viewModel.sections.count
        case .loading:
            return 0
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch state {
        case let .loaded(viewModel):
            let sectionModel = viewModel.sections[section]
            switch sectionModel {
            case let .active(_, cellViewModels):
                return cellViewModels.count
            case let .completed(_, cellViewModels):
                return cellViewModels.count
            case .yourContributions, .about, .error, .empty:
                return 1
            }
        case .loading:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch state {
        case let .loaded(viewModel):
            let sectionModel = viewModel.sections[indexPath.section]
            switch sectionModel {
            case let .active(_, cellViewModels), let .completed(_, cellViewModels):
                let cell = tableView.dequeueReusableCellWithType(CrowdloanTableViewCell.self)!
                let cellViewModel = cellViewModels[indexPath.row]
                cell.bind(viewModel: cellViewModel)
                return cell
            case let .yourContributions(model):
                let cell = tableView.dequeueReusableCellWithType(YourContributionsTableViewCell.self)!
                cell.view.bind(model: model)
                return cell
            case let .about(model):
                let cell = tableView.dequeueReusableCellWithType(AboutCrowdloansTableViewCell.self)!
                cell.view.bind(model: model)
                return cell
            case let .error(message):
                let cell: BlurredTableViewCell<ErrorStateView> = tableView.dequeueReusableCell(for: indexPath)
                cell.view.errorDescriptionLabel.text = message
                cell.view.delegate = self
                cell.view.locale = locale
                cell.applyStyle()
                return cell
            case .empty:
                let cell: BlurredTableViewCell<CrowdloanEmptyView> = tableView.dequeueReusableCell(for: indexPath)
                let text = R.string.localizable.crowdloanEmptyMessage_v3_9_1(preferredLanguages: locale.rLanguages)
                cell.view.bind(
                    image: R.image.iconEmptyHistory(),
                    text: text
                )
                cell.applyStyle()
                return cell
            }
        case .loading:
            return UITableViewCell()
        }
    }
}

extension CrowdloanListViewManager: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .loaded(viewModel) = state else {
            return
        }

        let sectionModel = viewModel.sections[indexPath.section]
        switch sectionModel {
        case let .active(_, cellViewModels):
            let viewModel = cellViewModels[indexPath.row]
            presenter?.selectCrowdloan(viewModel.paraId)
        case .yourContributions:
            presenter?.handleYourContributions()
        default:
            return
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case let .loaded(viewModel) = state else {
            return nil
        }

        let sectionModel = viewModel.sections[section]
        switch sectionModel {
        case let .active(title, cells), let .completed(title, cells):
            let headerView: CrowdloanStatusSectionView = tableView.dequeueReusableHeaderFooterView()
            headerView.bind(title: title, count: cells.count)
            return headerView
        case let .empty(title):
            let headerView: CrowdloanStatusSectionView = tableView.dequeueReusableHeaderFooterView()
            headerView.bind(title: title, count: 0)
            return headerView
        default:
            return nil
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard case let .loaded(viewModel) = state else {
            return 0.0
        }

        let sectionModel = viewModel.sections[section]
        switch sectionModel {
        case .active, .completed, .empty:
            return UITableView.automaticDimension
        default:
            return 0.0
        }
    }
}

extension CrowdloanListViewManager: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter?.refresh(shouldReset: true)
    }
}

extension CrowdloanListViewManager: CrowdloansViewProtocol {
    func didReceive(chainInfo: ChainBalanceViewModel) {
        chainSelectionView.bind(viewModel: chainInfo)
    }

    func didReceive(listState: CrowdloanListState) {
        state = listState

        tableView.reloadData()
    }
}

// TODO: Implement for Moonbeam coordinator
extension CrowdloanListViewManager: LoadableViewProtocol {
    var loadableContentView: UIView! {
        UIView()
    }

    var shouldDisableInteractionWhenLoading: Bool {
        false
    }

    func didStartLoading() {}

    func didStopLoading() {}
}

extension CrowdloanListViewManager: VoteChildViewProtocol {
    var isSetup: Bool {
        parent?.isSetup ?? false
    }

    var controller: UIViewController {
        parent?.controller ?? UIViewController()
    }

    func bind() {
        tableView.registerClassForCell(YourContributionsTableViewCell.self)
        tableView.registerClassForCell(AboutCrowdloansTableViewCell.self)
        tableView.registerClassForCell(CrowdloanTableViewCell.self)
        tableView.registerClassForCell(BlurredTableViewCell<CrowdloanEmptyView>.self)
        tableView.registerClassForCell(BlurredTableViewCell<ErrorStateView>.self)
        tableView.registerHeaderFooterView(withClass: CrowdloanStatusSectionView.self)

        tableView.dataSource = self
        tableView.delegate = self

        tableView.reloadData()
    }

    func unbind() {
        tableView.unregisterClassForCell(YourContributionsTableViewCell.self)
        tableView.unregisterClassForCell(AboutCrowdloansTableViewCell.self)
        tableView.unregisterClassForCell(CrowdloanTableViewCell.self)
        tableView.unregisterClassForCell(BlurredTableViewCell<CrowdloanEmptyView>.self)
        tableView.unregisterClassForCell(BlurredTableViewCell<ErrorStateView>.self)
        tableView.unregisterHeaderFooterView(withClass: CrowdloanStatusSectionView.self)

        tableView.dataSource = nil
        tableView.delegate = nil

        tableView.reloadData()
    }
}

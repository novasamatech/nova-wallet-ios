import Foundation
import UIKit
import Foundation_iOS

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
    private weak var parent: (ControllerBackedProtocol & LoadableViewProtocol)?
    private var viewModel: CrowdloansViewModel = .init(sections: [])

    init(
        tableView: UITableView,
        chainSelectionView: VoteChainViewProtocol,
        parent: ControllerBackedProtocol & LoadableViewProtocol
    ) {
        self.tableView = tableView
        self.chainSelectionView = chainSelectionView
        self.parent = parent

        super.init()
    }
}

extension CrowdloanListViewManager: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel.sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionModel = viewModel.sections[section]
        switch sectionModel {
        case let .active(_, cellViewModels):
            return cellViewModels.count
        case let .completed(_, cellViewModels):
            return cellViewModels.count
        case .yourContributions, .about, .error, .empty:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
            let text = R.string.localizable
                .crowdloanEmptyMessage_v3_9_1(preferredLanguages: locale.rLanguages)
            cell.view.bind(
                image: R.image.iconEmptyHistory(),
                text: text
            )
            cell.applyStyle()
            return cell
        }
    }
}

extension CrowdloanListViewManager: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let sectionModel = viewModel.sections[indexPath.section]
        switch sectionModel {
        case let .active(_, cellViewModels):
            guard let crowdloan = cellViewModels[indexPath.row].value else {
                return
            }
            presenter?.selectCrowdloan(crowdloan.paraId)
        case let .yourContributions(viewModel):
            guard viewModel.value != nil else {
                return
            }
            presenter?.handleYourContributions()
        default:
            return
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionModel = viewModel.sections[section]
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
        case let .empty(title):
            let headerView: VoteStatusSectionView = tableView.dequeueReusableHeaderFooterView()
            headerView.bind(viewModel: .loaded(value: .init(title: title, count: 0)))
            return headerView
        default:
            return nil
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let sectionModel = viewModel.sections[section]
        switch sectionModel {
        case let .active(state, _), let .completed(state, _):
            switch state {
            case .loading:
                return Constants.headerMinimumHeight
            case .loaded, .cached:
                return UITableView.automaticDimension
            }
        case .empty:
            return UITableView.automaticDimension
        default:
            return 0.0
        }
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt _: IndexPath) {
        (cell as? SkeletonableViewCell)?.updateLoadingState()
    }

    func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection _: Int) {
        (view as? SkeletonableView)?.updateLoadingState()
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sectionModel = viewModel.sections[indexPath.section]
        switch sectionModel {
        case .yourContributions:
            return Constants.yourContributionsRowHeight
        case let .active(_, model), let .completed(_, model):
            switch model[indexPath.row] {
            case .loading:
                return Constants.crowdloanRowMinimumHeight
            case .cached, .loaded:
                return UITableView.automaticDimension
            }
        default:
            return UITableView.automaticDimension
        }
    }
}

extension CrowdloanListViewManager: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter?.refresh(shouldReset: true)
    }
}

extension CrowdloanListViewManager: CrowdloansViewProtocol {
    func didReceive(chainInfo: SecuredViewModel<ChainBalanceViewModel>) {
        chainSelectionView.bind(viewModel: chainInfo)
    }

    func didReceive(listState: CrowdloansViewModel) {
        viewModel = listState

        tableView.reloadData()
    }
}

extension CrowdloanListViewManager: LoadableViewProtocol {
    var loadableContentView: UIView! {
        parent?.loadableContentView ?? UIView()
    }

    var shouldDisableInteractionWhenLoading: Bool {
        parent?.shouldDisableInteractionWhenLoading ?? false
    }

    func didStartLoading() {
        parent?.didStartLoading()
    }

    func didStopLoading() {
        parent?.didStopLoading()
    }
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
        tableView.registerHeaderFooterView(withClass: VoteStatusSectionView.self)

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
        tableView.unregisterHeaderFooterView(withClass: VoteStatusSectionView.self)

        tableView.dataSource = nil
        tableView.delegate = nil

        tableView.reloadData()
    }
}

extension CrowdloanListViewManager {
    enum Constants {
        static let yourContributionsRowHeight: CGFloat = 123
        static let crowdloanRowMinimumHeight: CGFloat = 145
        static let headerMinimumHeight: CGFloat = 56
    }
}

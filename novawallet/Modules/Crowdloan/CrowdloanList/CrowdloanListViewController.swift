import UIKit
import SoraFoundation
import SoraUI

final class CrowdloanListViewController: UIViewController, ViewHolder, LoadableViewProtocol {
    typealias RootViewType = CrowdloanListViewLayout

    let presenter: CrowdloanListPresenterProtocol

    private var chainInfo: CrowdloansChainViewModel?
    private var viewModel: CrowdloansViewModel = .init(sections: [])

    private var shouldUpdateOnAppearance: Bool = false

    init(
        presenter: CrowdloanListPresenterProtocol,
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
        view = CrowdloanListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if shouldUpdateOnAppearance {
            presenter.refresh(shouldReset: false)
        } else {
            shouldUpdateOnAppearance = true
        }

        presenter.becomeOnline()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        presenter.putOffline()
    }

    func configure() {
        rootView.tableView.registerClassForCell(YourContributionsTableViewCell.self)
        rootView.tableView.registerClassForCell(AboutCrowdloansTableViewCell.self)
        rootView.tableView.registerClassForCell(CrowdloanTableViewCell.self)
        rootView.tableView.registerClassForCell(BlurredTableViewCell<CrowdloanEmptyView>.self)
        rootView.tableView.registerClassForCell(BlurredTableViewCell<ErrorStateView>.self)
        rootView.tableView.registerHeaderFooterView(withClass: CrowdloanStatusSectionView.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        if let refreshControl = rootView.tableView.refreshControl {
            refreshControl.addTarget(self, action: #selector(actionRefresh), for: .valueChanged)
        }

        rootView.headerView.chainSelectionView.addTarget(
            self,
            action: #selector(actionSelectChain),
            for: .touchUpInside
        )

        rootView.headerView.walletSwitch.addTarget(
            self,
            action: #selector(actionWalletSwitch),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.headerView.titleLabel.text = R.string(preferredLanguages: languages).localizable.tabbarCrowdloanTitle_v190()
    }

    @objc func actionRefresh() {
        presenter.refresh(shouldReset: false)
    }

    @objc func actionSelectChain() {
        presenter.selectChain()
    }

    @objc func actionWalletSwitch() {
        presenter.handleWalletSwitch()
    }
}

extension CrowdloanListViewController: UITableViewDataSource {
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
            cell.view.locale = selectedLocale
            cell.applyStyle()
            return cell
        case .empty:
            let cell: BlurredTableViewCell<CrowdloanEmptyView> = tableView.dequeueReusableCell(for: indexPath)
            let text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.crowdloanEmptyMessage_v3_9_1()
            cell.view.bind(
                image: R.image.iconEmptyHistory(),
                text: text
            )
            cell.applyStyle()
            return cell
        }
    }
}

extension CrowdloanListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let sectionModel = viewModel.sections[indexPath.section]
        switch sectionModel {
        case let .active(_, cellViewModels):
            guard let crowdloan = cellViewModels[indexPath.row].value else {
                return
            }
            presenter.selectCrowdloan(crowdloan.paraId)
        case let .yourContributions(viewModel):
            guard viewModel.value != nil else {
                return
            }
            presenter.handleYourContributions()
        default:
            return
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionModel = viewModel.sections[section]
        switch sectionModel {
        case let .active(title, cells), let .completed(title, cells):
            let headerView: CrowdloanStatusSectionView = tableView.dequeueReusableHeaderFooterView()
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
            let headerView: CrowdloanStatusSectionView = tableView.dequeueReusableHeaderFooterView()
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

extension CrowdloanListViewController: CrowdloanListViewProtocol {
    func didReceive(walletSwitchViewModel: WalletSwitchViewModel) {
        rootView.headerView.walletSwitch.bind(viewModel: walletSwitchViewModel)
    }

    func didReceive(chainInfo: CrowdloansChainViewModel) {
        self.chainInfo = chainInfo

        rootView.headerView.bind(viewModel: chainInfo)
        rootView.headerView.setNeedsLayout()
    }

    func didReceive(listState: CrowdloansViewModel) {
        viewModel = listState

        if listState.sections.allSatisfy({ !$0.isLoading }) {
            rootView.tableView.refreshControl?.endRefreshing()
        }

        rootView.tableView.reloadData()
    }
}

extension CrowdloanListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension CrowdloanListViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.refresh(shouldReset: true)
    }
}

extension CrowdloanListViewController: HiddableBarWhenPushed {}

extension CrowdloanListViewController {
    enum Constants {
        static let yourContributionsRowHeight: CGFloat = 123
        static let crowdloanRowMinimumHeight: CGFloat = 145
        static let headerMinimumHeight: CGFloat = 56
    }
}

import UIKit
import SoraFoundation
import SoraUI

final class CrowdloanListViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanListViewLayout

    let presenter: CrowdloanListPresenterProtocol

    private var chainInfo: CrowdloansChainViewModel?
    private var state: CrowdloanListState = .loading

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
        applyState()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if case .loading = state {
            didStartLoading()
        }
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

        if case .loading = state {
            didStopLoading()
        }
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
        rootView.headerView.titleLabel.text = R.string.localizable
            .tabbarCrowdloanTitle_v190(preferredLanguages: languages)
    }

    private func applyState() {
        switch state {
        case .loading:
            didStartLoading()
        case .loaded:
            rootView.tableView.refreshControl?.endRefreshing()
            didStopLoading()
        }

        rootView.tableView.reloadData()
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
                cell.view.locale = selectedLocale
                cell.applyStyle()
                return cell
            case .empty:
                let cell: BlurredTableViewCell<CrowdloanEmptyView> = tableView.dequeueReusableCell(for: indexPath)
                let text = R.string.localizable
                    .crowdloanEmptyMessage_v3_9_1(preferredLanguages: selectedLocale.rLanguages)
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

extension CrowdloanListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .loaded(viewModel) = state else {
            return
        }

        let sectionModel = viewModel.sections[indexPath.section]
        switch sectionModel {
        case let .active(_, cellViewModels):
            let viewModel = cellViewModels[indexPath.row]
            presenter.selectCrowdloan(viewModel.paraId)
        case .yourContributions:
            presenter.handleYourContributions()
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

extension CrowdloanListViewController: CrowdloanListViewProtocol {
    func didReceive(walletSwitchViewModel: WalletSwitchViewModel) {
        rootView.headerView.walletSwitch.bind(viewModel: walletSwitchViewModel)
    }

    func didReceive(chainInfo: CrowdloansChainViewModel) {
        self.chainInfo = chainInfo

        rootView.headerView.bind(viewModel: chainInfo)
        rootView.headerView.setNeedsLayout()
    }

    func didReceive(listState: CrowdloanListState) {
        state = listState

        applyState()
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

extension CrowdloanListViewController: LoadableViewProtocol {}
extension CrowdloanListViewController: HiddableBarWhenPushed {}

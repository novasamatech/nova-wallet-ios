import Foundation
import Foundation_iOS

final class SwapTokenSelectPresenter {
    weak var view: SwapTokenSelectViewProtocol?
    let wireframe: SwapTokenSelectWireframeProtocol
    let interactor: SwapTokenSelectInteractorInputProtocol
    let viewModelFactory: SwapTokenSelectViewModelFactoryProtocol
    let side: SwapTokenSelectionSide
    let context: SwapTokenSelectionContext
    let completion: (SwapTokenSelectionResult) -> Void
    let logger: LoggerProtocol

    private var assetList: AssetListModel?
    private var routeUniverse: Set<ChainAssetId>?
    private var swappable: Set<ChainAssetId>?
    private var savedNetworks: [ChainModel.Id] = []
    private var selectedNetworks: Set<ChainModel.Id> = []
    private var query: String = ""
    private var list: SwapTokenSelectList?
    private var pendingSelection: ChainAsset?
    private var isFinished = false
    private var needsRoutesRefresh = false
    private var isRoutesRetryShown = false
    private var balancesLoadingTimedOut = false
    private lazy var balancesLoadingScheduler = Scheduler(with: self, callbackQueue: .main)

    init(
        interactor: SwapTokenSelectInteractorInputProtocol,
        wireframe: SwapTokenSelectWireframeProtocol,
        viewModelFactory: SwapTokenSelectViewModelFactoryProtocol,
        side: SwapTokenSelectionSide,
        context: SwapTokenSelectionContext,
        completion: @escaping (SwapTokenSelectionResult) -> Void,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.side = side
        self.context = context
        self.completion = completion
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

// MARK: Private

private extension SwapTokenSelectPresenter {
    func provideTitle() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        let title = switch side {
        case .pay:
            strings.swapsSetupAssetActionSelectPay()
        case .receive:
            strings.swapsSetupAssetActionSelectReceive()
        }

        view?.didReceive(title: title)
    }

    func rebuildList() {
        list = assetList.flatMap { assetList in
            SwapTokenSelectListBuilder.build(
                from: SwapTokenSelectListParams(
                    side: side,
                    context: context,
                    assetList: assetList,
                    routeUniverse: routeUniverse,
                    swappable: swappable,
                    query: query,
                    networkFilter: selectedNetworks,
                    showsPendingBalances: !balancesLoadingTimedOut
                )
            )
        }

        scheduleBalancesLoadingTimeoutIfNeeded()
        provideList()
        provideChips()
    }

    func scheduleBalancesLoadingTimeoutIfNeeded() {
        guard list?.balancesLoading == true, !balancesLoadingScheduler.isScheduled else {
            return
        }

        balancesLoadingScheduler.notifyAfter(Constants.balancesLoadingTimeout)
    }

    func provideList() {
        let params = SwapTokenSelectListViewModelParams(
            currentChainAssetId: context.current?.chainAssetId,
            pendingChainAssetId: pendingSelection?.chainAssetId,
            counterpartSymbol: context.counterpart?.asset.symbol,
            isSearching: !query.isEmpty,
            isFiltering: !selectedNetworks.isEmpty
        )

        let viewModel = viewModelFactory.createListViewModel(
            from: list,
            params: params,
            locale: selectedLocale
        )

        view?.didReceive(list: viewModel)
    }

    func provideChips() {
        let chipRow = SwapTokenSelectNetworksArranger.chipRow(
            from: list?.networks ?? [],
            savedNetworks: savedNetworks
        )

        let viewModels = viewModelFactory.createChipViewModels(
            from: chipRow,
            selectedNetworks: selectedNetworks,
            locale: selectedLocale
        )

        view?.didReceive(chips: viewModels)
    }

    func showNetworkSelection() {
        guard let networks = list?.networks else {
            return
        }

        let viewModels = viewModelFactory.createNetworkViewModels(
            from: SwapTokenSelectNetworksArranger.sheetOrder(of: networks),
            selectedNetworks: SwapTokenSelectNetworksArranger.sheetSelection(
                savedNetworks: savedNetworks,
                selectedNetworks: selectedNetworks
            )
        )

        let shownNetworks = Set(networks.map(\.chainId))

        wireframe.showNetworkSelection(from: view, viewModels: viewModels) { [weak self] chainIds in
            self?.selectedNetworks = Set(chainIds)
            self?.interactor.save(networks: chainIds, replacing: shownNetworks)
            self?.view?.didCompleteNetworkSelection()
        }
    }

    func findChainAsset(for chainAssetId: ChainAssetId) -> ChainAsset? {
        guard let list else {
            return nil
        }

        let items = list.yourTokens + list.otherTokens + list.notSwappable

        return items.first { $0.chainAsset.chainAssetId == chainAssetId }?.chainAsset
    }

    func completeSelectionIfPossible(of chainAsset: ChainAsset) {
        guard context.counterpart != nil else {
            complete(with: .selected(chainAsset))
            return
        }

        guard let swappable else {
            pendingSelection = chainAsset
            provideList()
            refreshRoutesIfFailed()
            return
        }

        if swappable.contains(chainAsset.chainAssetId) {
            complete(with: .selected(chainAsset))
        } else {
            complete(with: .selectedClearingCounterpart(chainAsset))
        }
    }

    func complete(with result: SwapTokenSelectionResult) {
        guard !isFinished else {
            return
        }

        finish()
        completion(result)
    }

    func finish() {
        isFinished = true
        pendingSelection = nil
        wireframe.close(view: view)
    }

    func refreshRoutesIfFailed() {
        isRoutesRetryShown = false

        guard needsRoutesRefresh else {
            return
        }

        needsRoutesRefresh = false
        interactor.refreshRoutes()
    }
}

// MARK: SwapTokenSelectPresenterProtocol

extension SwapTokenSelectPresenter: SwapTokenSelectPresenterProtocol {
    func setup() {
        provideTitle()
        provideList()
        provideChips()

        interactor.setup()
    }

    func search(query: String) {
        self.query = query
        rebuildList()
    }

    func selectChip(_ kind: SwapTokenSelectChipViewModel.Kind) {
        switch kind {
        case .all:
            selectedNetworks = []
        case let .network(chainId):
            selectedNetworks = [chainId]
        case .more:
            showNetworkSelection()
            return
        }

        rebuildList()
    }

    func selectToken(with chainAssetId: ChainAssetId) {
        guard !isFinished, let chainAsset = findChainAsset(for: chainAssetId) else {
            return
        }

        if chainAssetId == context.current?.chainAssetId {
            finish()
        } else {
            completeSelectionIfPossible(of: chainAsset)
        }
    }

    func selectLoadingRow() {
        refreshRoutesIfFailed()
    }

    func close() {
        guard !isFinished else {
            return
        }

        finish()
    }
}

// MARK: SwapTokenSelectInteractorOutputProtocol

extension SwapTokenSelectPresenter: SwapTokenSelectInteractorOutputProtocol {
    func didReceive(assetList: AssetListModel) {
        self.assetList = assetList
        rebuildList()
    }

    func didReceive(routeUniverse: Set<ChainAssetId>) {
        self.routeUniverse = routeUniverse
        rebuildList()
    }

    func didReceive(swappable: Set<ChainAssetId>) {
        self.swappable = swappable
        rebuildList()

        if let pendingSelection {
            completeSelectionIfPossible(of: pendingSelection)
        }
    }

    func didReceive(savedNetworks: [ChainModel.Id]) {
        self.savedNetworks = savedNetworks
        rebuildList()
    }

    func didReceive(error: SwapTokenSelectError) {
        logger.error("Token select error: \(error)")

        needsRoutesRefresh = true

        if pendingSelection != nil {
            pendingSelection = nil
            provideList()
        }

        guard !isRoutesRetryShown else {
            return
        }

        isRoutesRetryShown = wireframe.presentRoutesRetry(
            on: view,
            locale: selectedLocale,
            retryAction: { [weak self] in
                self?.refreshRoutesIfFailed()
            },
            skipAction: { [weak self] in
                self?.isRoutesRetryShown = false
            }
        )
    }
}

// MARK: SchedulerDelegate

extension SwapTokenSelectPresenter: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        balancesLoadingTimedOut = true
        rebuildList()
    }
}

// MARK: Localizable

extension SwapTokenSelectPresenter: Localizable {
    func applyLocalization() {
        guard view?.isSetup == true else {
            return
        }

        provideTitle()
        provideList()
        provideChips()
    }
}

// MARK: Constants

private extension SwapTokenSelectPresenter {
    enum Constants {
        static let balancesLoadingTimeout: TimeInterval = 3
    }
}

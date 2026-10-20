import Foundation
import Foundation_iOS

final class SubtensorPortfolioPresenter {
    weak var view: SubtensorPortfolioViewProtocol?

    let interactor: SubtensorPortfolioInteractorInputProtocol
    let wireframe: SubtensorPortfolioWireframeProtocol
    let viewModelFactory: SubtensorPortfolioViewModelFactoryProtocol
    let wallet: MetaAccountModel
    let account: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let localizationManager: LocalizationManagerProtocol

    private var state = SubtensorPortfolioState()
    private var weeklyChangesRequest: [SubtensorSubnetRef]?
    private var historiesPeriod: SubtensorPricePeriod?
    private var isRootYieldsRequested = false
    private var isNetworkRootRateRequested = false
    private var chartSelection: SubtensorPortfolioChartSelection?
    let dataAnalytics = SubtensorDataAnalytics(screen: .portfolio)

    init(
        interactor: SubtensorPortfolioInteractorInputProtocol,
        wireframe: SubtensorPortfolioWireframeProtocol,
        viewModelFactory: SubtensorPortfolioViewModelFactoryProtocol,
        wallet: MetaAccountModel,
        account: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.account = account
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }
}

private extension SubtensorPortfolioPresenter {
    func provideViewModel() {
        chartSelection = nil

        let viewModel = viewModelFactory.createViewModel(for: state, locale: localizationManager.selectedLocale)
        view?.didReceive(viewModel: viewModel)
    }

    func requestRootRateIfNeeded() {
        guard state.positions != nil else {
            return
        }

        let groups = state.groups

        if groups.isEmpty, !isNetworkRootRateRequested {
            isNetworkRootRateRequested = true
            interactor.loadNetworkRootRate()
        } else if !isRootYieldsRequested, groups.contains(where: { $0.netuid == SubtensorPallet.rootNetuid }) {
            isRootYieldsRequested = true
            interactor.loadRootYields()
        }
    }

    func requestPriceDataIfNeeded() {
        guard state.positions != nil, state.isCatalogueResolved else {
            return
        }

        let subnets = state.subnetRefs

        if weeklyChangesRequest != subnets {
            weeklyChangesRequest = subnets
            interactor.loadWeeklyChanges(for: subnets)
        }

        guard chainAsset.asset.priceId != nil, historiesPeriod != state.period else {
            return
        }

        historiesPeriod = state.period
        state.histories = .loading
        interactor.loadHistories(for: state.period)
    }

    func refetchLoadedHistories() {
        guard historiesPeriod == state.period else {
            return
        }

        interactor.loadHistories(for: state.period)
    }
}

extension SubtensorPortfolioPresenter: SubtensorPortfolioPresenterProtocol {
    func setup() {
        provideViewModel()
        interactor.setup()
    }

    func selectPeriod(at index: Int) {
        guard
            SubtensorPricePeriod.portfolioSelectable.indices.contains(index),
            SubtensorPricePeriod.portfolioSelectable[index] != state.period else {
            return
        }

        state.period = SubtensorPricePeriod.portfolioSelectable[index]
        state.histories = .loading
        requestPriceDataIfNeeded()
        provideViewModel()
    }

    func selectPosition(at index: Int) {
        let groups = state.groups

        guard groups.indices.contains(index) else {
            return
        }

        wireframe.showPosition(from: view, group: groups[index])
    }

    func addPosition() {
        wireframe.checkingSubtensorStakingSupport(
            for: wallet,
            chain: chainAsset.chain,
            sheetPresentingView: view,
            onRefusal: { [weak self] reason in
                self?.trackAddPositionRefusal(reason)
            },
            successClosure: { [weak self] in
                self?.trackAddPositionOpened()
                self?.wireframe.showAddPosition(from: self?.view)
            }
        )
    }

    func retry() {
        isRootYieldsRequested = false
        isNetworkRootRateRequested = false
        interactor.refresh()
        requestRootRateIfNeeded()
    }

    func refresh() {
        isRootYieldsRequested = false
        isNetworkRootRateRequested = false
        weeklyChangesRequest = nil

        interactor.refreshAll()
        requestRootRateIfNeeded()
        refetchLoadedHistories()
        requestPriceDataIfNeeded()
        provideViewModel()
    }

    func selectChartPoint(at index: Int?) {
        state.chartPoint = index

        if chartSelection == nil {
            chartSelection = viewModelFactory.createChartSelection(for: state, locale: selectedLocale)
        }

        guard let chartSelection else {
            return
        }

        let header = viewModelFactory.createHeader(for: chartSelection, state: state, locale: selectedLocale)

        view?.didReceive(header: header)
    }
}

extension SubtensorPortfolioPresenter: SubtensorPortfolioInteractorOutputProtocol {
    func didReceive(state positions: Multistaking.SubtensorState) {
        state.positions = positions
        requestRootRateIfNeeded()
        requestPriceDataIfNeeded()
        provideViewModel()
    }

    func didReceive(prices: SubtensorAlphaPrices?) {
        state.isCatalogueResolved = true
        state.prices = prices

        requestPriceDataIfNeeded()
        provideViewModel()
    }

    func didReceive(subnetLogos: SubtensorSubnetLogos?) {
        state.subnetLogos = subnetLogos
        provideViewModel()
    }

    func didReceive(rootYields: SubtensorAlphaYields?) {
        state.rootYields = rootYields
        state.isRootRateResolved = true
        isRootYieldsRequested = rootYields != nil
        provideViewModel()
    }

    func didReceive(networkRootRate: Decimal?) {
        state.networkRootRate = networkRootRate
        isNetworkRootRateRequested = networkRootRate != nil
        provideViewModel()
    }

    func didReceive(price: PriceData?) {
        state.price = .loaded(price)
        provideViewModel()
    }

    func didReceive(histories: SubtensorPortfolioPriceHistories) {
        guard histories.period == state.period else {
            return
        }

        state.histories = .loaded(histories)
        provideViewModel()
    }

    func didFailHistories(for period: SubtensorPricePeriod, error: Error?) {
        guard period == state.period, state.histories == .loading else {
            return
        }

        dataAnalytics.trackFailure(error, endpoint: error is BittensorApiError ? .portfolioHistory : .coingecko)

        historiesPeriod = nil
        state.histories = .failed
        provideViewModel()
    }

    func didReceive(weeklyChanges: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]) {
        state.weeklyChanges = weeklyChanges
        provideViewModel()
    }

    func didFailWeeklyChanges() {
        weeklyChangesRequest = nil
    }

    func didReceiveSyncFailure(_ isFailed: Bool) {
        state.isSyncFailed = isFailed
        provideViewModel()
    }

    func didReceivePositionsSyncing(_ isSyncing: Bool) {
        if !isSyncing {
            view?.didCompleteRefreshing()
        }
    }

    func didChangeCurrency() {
        state.price = .loading
        state.histories = .loading
        historiesPeriod = nil
        requestPriceDataIfNeeded()
        provideViewModel()
    }

    func didReceiveAccountChange() {
        wireframe.close(from: view)
    }

    func didBecomeActive() {
        isRootYieldsRequested = false
        isNetworkRootRateRequested = false
        requestRootRateIfNeeded()
    }

    func didChangeStake() {
        refetchLoadedHistories()
    }
}

extension SubtensorPortfolioPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideViewModel()
        }
    }
}

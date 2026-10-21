import Foundation
import Foundation_iOS
import NovaAnalytics

final class SubtensorSubnetSelectPresenter {
    weak var view: SubtensorSubnetSelectViewProtocol?
    weak var delegate: SubtensorSubnetSelectDelegate?

    let wireframe: SubtensorSubnetSelectWireframeProtocol
    let interactor: SubtensorSubnetSelectInteractorInputProtocol
    let viewModelFactory: SubtensorSubnetViewModelFactoryProtocol
    let chainAsset: ChainAsset

    let abandonTracker: AnalyticsAbandonTracker?

    let dataAnalytics = SubtensorDataAnalytics(screen: .subnetSelect)
    let source: SubnetListSource
    var isSearchTracked = false

    private var entries: [SubtensorSubnetListItem]?
    private var entriesError: Error?
    private var weeklyPrices: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]?
    private var apy: [UInt16: Decimal]?
    private var isApyPending = false
    private var subnetLogos: SubtensorSubnetLogos?
    private var favourites: Set<SubtensorSubnetRef> = []
    private var query = ""
    let browseState: SubtensorSubnetBrowseState
    private var sort: SubtensorSubnetSort { browseState.sort }
    private var filters: SubtensorSubnetFilters { browseState.filters }
    private var list: SubtensorSubnetList?

    private var requestedWeeklySubnets: Set<SubtensorSubnetRef> = []
    private var isWeeklyPending = false

    init(
        interactor: SubtensorSubnetSelectInteractorInputProtocol,
        wireframe: SubtensorSubnetSelectWireframeProtocol,
        viewModelFactory: SubtensorSubnetViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        delegate: SubtensorSubnetSelectDelegate,
        localizationManager: LocalizationManagerProtocol,
        browseState: SubtensorSubnetBrowseState,
        source: SubnetListSource
    ) {
        self.browseState = browseState
        self.chainAsset = chainAsset
        self.source = source
        abandonTracker = source == .seeAllOptions ? AnalyticsAbandonTracker(makeEvent: Self.abandonEvent) : nil
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.delegate = delegate

        self.localizationManager = localizationManager
    }
}

private extension SubtensorSubnetSelectPresenter {
    func makeBuilder() -> SubtensorSubnetListBuilder? {
        guard let entries else {
            return nil
        }

        return SubtensorSubnetListBuilder(
            entries: entries,
            weekly: weeklyPrices,
            apy: apy,
            previousOrder: browseState.orderedRefs,
            favourites: favourites,
            locale: selectedLocale
        )
    }

    func provideList() {
        let builder = makeBuilder()
        list = builder?.build(query: query, sort: sort, filters: filters)
        if let builder { browseState.orderedRefs = builder.orderedRefs(sort: sort) }

        let state = SubtensorSubnetListState(
            list: list,
            sort: sort,
            filters: filters,
            subnetLogos: subnetLogos,
            stamp: entries.flatMap { SubtensorBackendStamp.aggregate($0.flatMap(\.subnet.stamps)) },
            entriesError: entriesError
        )

        view?.didReceive(list: viewModelFactory.createListViewModel(for: state, locale: selectedLocale))
    }

    func requestWeeklyPricesIfNeeded() {
        guard let entries, !isWeeklyPending else {
            return
        }

        let subnets = entries.map(\.subnet.ref).filter { !requestedWeeklySubnets.contains($0) }

        guard !subnets.isEmpty else {
            return
        }

        requestedWeeklySubnets.formUnion(subnets)
        isWeeklyPending = true

        interactor.loadWeeklyPrices(for: subnets)
    }

    func requestApyIfNeeded() {
        guard sort == .apy, apy == nil, !isApyPending else {
            return
        }

        isApyPending = true

        interactor.loadApy()
    }

    func applySort(_ newSort: SubtensorSubnetSort) {
        browseState.sort = newSort

        provideList()
        requestApyIfNeeded()
    }

    func findItem(for subnetRef: SubtensorSubnetRef) -> SubtensorSubnetListItem? {
        guard let list else {
            return nil
        }

        return (list.picks + list.others).first { $0.ref == subnetRef }
    }
}

extension SubtensorSubnetSelectPresenter: SubtensorSubnetSelectPresenterProtocol {
    func setup() {
        trackListOpened()
        provideList()
        requestApyIfNeeded()

        interactor.setup()
    }

    func becomeActive() {
        abandonTracker?.makeEvent = Self.abandonEvent
        interactor.refreshFavourites()
    }

    func search(query: String) {
        self.query = query
        trackSearchIfNeeded(query)

        provideList()
    }

    func selectSubnet(_ subnetRef: SubtensorSubnetRef) {
        guard let delegate, let item = findItem(for: subnetRef) else {
            return
        }

        wireframe.showDetails(from: view, item: item, abandonTracker: abandonTracker, delegate: delegate)
    }

    func toggleFavorite(_ subnetRef: SubtensorSubnetRef) {
        trackInteraction(favourites.contains(subnetRef) ? .favoriteRemoved : .favoriteAdded)
        interactor.toggleFavorite(subnetRef)
    }

    func selectRoot() {
        trackRootSelected()
        wireframe.complete(from: view, target: .root, validator: nil, recommendedHotkey: nil, delegate: delegate)
    }

    func showSort() {
        let viewModel = viewModelFactory.createSortSheetViewModel(selected: sort, locale: selectedLocale)

        wireframe.showSortSheet(from: view, viewModel: viewModel, delegate: self)
    }

    func showFilters() {
        wireframe.showFilters(from: view, filters: filters, delegate: self)
    }

    func retry() {
        dataAnalytics.trackRetry(.subnets)
        entries = nil
        entriesError = nil
        provideList()

        interactor.refresh()
    }
}

extension SubtensorSubnetSelectPresenter: SubtensorSubnetSelectInteractorOutputProtocol {
    func didReceive(entries: [SubtensorSubnetListItem]) {
        self.entries = entries
        entriesError = nil

        provideList()
        requestWeeklyPricesIfNeeded()
    }

    func didReceive(favourites: Set<SubtensorSubnetRef>) {
        guard favourites != self.favourites else {
            return
        }

        self.favourites = favourites

        provideList()
    }

    func didReceive(subnetLogos: SubtensorSubnetLogos?) {
        self.subnetLogos = subnetLogos

        provideList()
    }

    func didReceive(weeklyPrices: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]) {
        self.weeklyPrices = (self.weeklyPrices ?? [:]).merging(weeklyPrices) { _, new in new }
        isWeeklyPending = false

        provideList()
        requestWeeklyPricesIfNeeded()
    }

    func didReceive(apy: [UInt16: Decimal]?) {
        self.apy = apy?.isEmpty == false ? apy : nil
        isApyPending = false

        provideList()
    }

    func didReceiveError(_ error: Error) {
        entries = nil
        entriesError = error
        provideList()

        dataAnalytics.trackFailure(error, endpoint: .subnets)
    }
}

extension SubtensorSubnetSelectPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else {
            return
        }

        provideList()
    }
}

extension SubtensorSubnetSelectPresenter: SubtensorSortSheetDelegate {
    func sortSheetDidSelectOption(at index: Int) {
        let sorts = SubtensorSubnetSort.allCases

        guard sorts.indices.contains(index) else {
            return
        }

        trackInteraction(.sort(sorts[index].analyticsKey))
        applySort(sorts[index])
    }
}

extension SubtensorSubnetSelectPresenter: SubtensorSubnetFiltersDelegate {
    func countSubnets(matching filters: SubtensorSubnetFilters) -> Int? {
        makeBuilder()?.build(query: query, sort: sort, filters: filters).count
    }

    func didReceiveSubnet(filters: SubtensorSubnetFilters) {
        if filters.hideThinPools != browseState.filters.hideThinPools {
            trackInteraction(.filterThinPools(filters.hideThinPools))
        }

        browseState.filters = filters

        provideList()
    }
}
